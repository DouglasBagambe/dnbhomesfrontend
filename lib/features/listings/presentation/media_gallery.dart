import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../domain/property.dart';
import '../../../core/navigation_observer.dart';

class MediaGallery extends StatefulWidget {
  const MediaGallery(
      {super.key,
      required this.media,
      required this.title,
      this.initialIndex = 0,
      this.fullscreen = false});
  final List<PropertyMedia> media;
  final String title;
  final int initialIndex;
  final bool fullscreen;
  @override
  State<MediaGallery> createState() => _MediaGalleryState();
}

class _MediaGalleryState extends State<MediaGallery> {
  late final page = PageController(initialPage: widget.initialIndex);
  late int index = widget.initialIndex;
  final video = GlobalKey<_MediaVideoState>();
  @override
  void dispose() {
    page.dispose();
    super.dispose();
  }

  Future<void> fullscreen() async {
    video.currentState?.pause();
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Property media')),
                  body: SafeArea(
                      child: MediaGallery(
                          media: widget.media,
                          title: widget.title,
                          initialIndex: index,
                          fullscreen: true)),
                )));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.media.isEmpty)
      return const ColoredBox(
          color: Colors.black12,
          child: Center(child: Icon(Icons.home_work_outlined, size: 64)));
    final images = widget.media.where((m) => m.type == 'image').length;
    return Stack(fit: StackFit.expand, children: [
      PageView.builder(
          controller: page,
          itemCount: widget.media.length,
          onPageChanged: (value) => setState(() => index = value),
          itemBuilder: (_, i) {
            final item = widget.media[i];
            if (item.type == 'video')
              return i == index
                  ? _MediaVideo(
                      key: video,
                      url: item.url,
                      label: item.alt ?? 'Property video')
                  : const ColoredBox(
                      color: Colors.black,
                      child: Center(
                          child: Icon(Icons.play_circle_outline,
                              color: Colors.white, size: 64)));
            return GestureDetector(
                onTap: widget.fullscreen ? null : fullscreen,
                child: Semantics(
                    image: true,
                    label: item.alt ?? '${widget.title}, image ${i + 1}',
                    child: CachedNetworkImage(
                        imageUrl: item.url,
                        fit: widget.fullscreen ? BoxFit.contain : BoxFit.cover,
                        memCacheWidth: 1400,
                        placeholder: (_, __) =>
                            const Center(child: Icon(Icons.photo_outlined)),
                        errorWidget: (_, __, ___) =>
                            const Center(child: Text('Image unavailable')))));
          }),
      Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Row(children: [
            if (widget.fullscreen)
              IconButton.filled(
                  tooltip: 'Previous media',
                  onPressed: () => page.animateToPage(
                      (index - 1 + widget.media.length) % widget.media.length,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut),
                  icon: const Icon(Icons.chevron_left)),
            const Spacer(),
            Container(
                padding: const EdgeInsets.all(8),
                color: Colors.black87,
                child: Text(
                    '${index + 1} / ${widget.media.length} · ${widget.media[index].type == "video" ? "Video" : "Image"}\n$images images · ${widget.media.length - images} videos',
                    style: const TextStyle(color: Colors.white, fontSize: 12))),
            if (!widget.fullscreen)
              IconButton.filled(
                  tooltip: 'Open full gallery',
                  onPressed: fullscreen,
                  icon: const Icon(Icons.fullscreen)),
            if (widget.fullscreen)
              IconButton.filled(
                  tooltip: 'Next media',
                  onPressed: () => page.animateToPage(
                      (index + 1) % widget.media.length,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut),
                  icon: const Icon(Icons.chevron_right)),
          ])),
    ]);
  }
}

class _MediaVideo extends StatefulWidget {
  const _MediaVideo({super.key, required this.url, required this.label});
  final String url, label;
  @override
  State<_MediaVideo> createState() => _MediaVideoState();
}

class _MediaVideoState extends State<_MediaVideo>
    with WidgetsBindingObserver, RouteAware {
  VideoPlayerController? controller;
  bool loading = false, failed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) pause();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) homesRouteObserver.subscribe(this, route);
  }

  @override
  void didPushNext() => pause();
  @override
  void didPop() => pause();
  @override
  void didUpdateWidget(covariant _MediaVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      controller?.dispose();
      controller = null;
      loading = false;
      failed = false;
    }
  }

  void pause() {
    controller?.pause();
  }

  Future<void> play() async {
    if (loading) return;
    await controller?.dispose();
    if (!mounted) return;
    final player = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    setState(() {
      controller = player;
      loading = true;
      failed = false;
    });
    try {
      await player.initialize().timeout(const Duration(seconds: 30));
      if (!mounted || controller != player) return;
      await player.play();
      if (!mounted || controller != player) return;
      setState(() => loading = false);
    } catch (_) {
      if (mounted && controller == player) {
        await player.dispose();
        if (!mounted || controller != player) return;
        setState(() {
          controller = null;
          loading = false;
          failed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    homesRouteObserver.unsubscribe(this);
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = controller;
    return ColoredBox(
        color: Colors.black,
        child: Padding(
            padding: const EdgeInsets.only(bottom: 80, top: 60),
            child: Center(
              child: loading
                  ? const CircularProgressIndicator()
                  : player == null
                      ? Column(mainAxisSize: MainAxisSize.min, children: [
                          if (failed)
                            const Text('Video unavailable. Try again.',
                                style: TextStyle(color: Colors.white)),
                          IconButton.filled(
                              tooltip: failed ? 'Retry video' : 'Play video',
                              onPressed: play,
                              iconSize: 64,
                              icon: const Icon(Icons.play_circle_outline))
                        ])
                      : ValueListenableBuilder<VideoPlayerValue>(
                          valueListenable: player,
                          builder: (_, value, __) => value.hasError
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                      const Text(
                                          'Video unavailable. Try again.',
                                          style:
                                              TextStyle(color: Colors.white)),
                                      IconButton.filled(
                                          tooltip: 'Retry video',
                                          onPressed: play,
                                          icon: const Icon(Icons.refresh)),
                                    ])
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                      Flexible(
                                          child: AspectRatio(
                                              aspectRatio: value.aspectRatio,
                                              child: Semantics(
                                                  label: widget.label,
                                                  child: VideoPlayer(player)))),
                                      VideoProgressIndicator(player,
                                          allowScrubbing: true,
                                          padding: const EdgeInsets.all(12)),
                                      IconButton.filled(
                                          tooltip: value.isPlaying
                                              ? 'Pause video'
                                              : 'Play video',
                                          onPressed: () => value.isPlaying
                                              ? player.pause()
                                              : player.play(),
                                          icon: Icon(value.isPlaying
                                              ? Icons.pause
                                              : Icons.play_arrow)),
                                    ])),
            )));
  }
}
