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
      this.fullscreen = false,
      this.active = true,
      this.immersive = false,
      this.onIndexChanged});
  final List<PropertyMedia> media;
  final String title;
  final int initialIndex;
  final bool fullscreen;
  final bool active, immersive;
  final ValueChanged<int>? onIndexChanged;
  @override
  State<MediaGallery> createState() => _MediaGalleryState();
}

class _MediaGalleryState extends State<MediaGallery> {
  late final page = PageController(initialPage: widget.initialIndex);
  late int index = widget.initialIndex;
  final video = GlobalKey<_MediaVideoState>();
  void navigate(int next) {
    if (MediaQuery.disableAnimationsOf(context)) {
      page.jumpToPage(next);
    } else {
      page.animateToPage(next,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

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
          onPageChanged: (value) {
            video.currentState?.pause();
            setState(() => index = value);
            widget.onIndexChanged?.call(value);
          },
          itemBuilder: (_, i) {
            final item = widget.media[i];
            if (item.type == 'video')
              return widget.active && i == index
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
                        fit: widget.fullscreen && !widget.immersive
                            ? BoxFit.contain
                            : BoxFit.cover,
                        memCacheWidth: widget.immersive ? 1000 : 1400,
                        placeholder: (_, __) =>
                            const Center(child: Icon(Icons.photo_outlined)),
                        errorWidget: (_, __, ___) =>
                            const Center(child: Text('Image unavailable')))));
          }),
      if (!widget.immersive)
        Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Row(children: [
              if (widget.fullscreen)
                IconButton.filled(
                    tooltip: 'Previous media',
                    onPressed: () => navigate(
                        (index - 1 + widget.media.length) %
                            widget.media.length),
                    icon: const Icon(Icons.chevron_left)),
              const SizedBox(width: 4),
              Expanded(
                  child: Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.black87,
                      child: Text(
                          '${index + 1} / ${widget.media.length} · ${widget.media[index].type == "video" ? "Video" : "Image"}\n$images images · ${widget.media.length - images} videos',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)))),
              if (!widget.fullscreen)
                IconButton.filled(
                    tooltip: 'Open full gallery',
                    onPressed: fullscreen,
                    icon: const Icon(Icons.fullscreen)),
              if (widget.fullscreen)
                IconButton.filled(
                    tooltip: 'Next media',
                    onPressed: () =>
                        navigate((index + 1) % widget.media.length),
                    icon: const Icon(Icons.chevron_right)),
            ])),
      if (widget.immersive)
        Positioned(
            top: 12,
            right: 12,
            child: Semantics(
                label:
                    'Media ${index + 1} of ${widget.media.length}, $images images and ${widget.media.length - images} videos',
                child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    color: Colors.black54,
                    child: Text('${index + 1} / ${widget.media.length}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12))))),
      if (widget.immersive && widget.media.length > 1)
        Positioned(
            left: 8,
            right: 8,
            top: 0,
            bottom: 0,
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton.filled(
                      tooltip: 'Previous media',
                      onPressed: index == 0 ? null : () => navigate(index - 1),
                      icon: const Icon(Icons.chevron_left)),
                  IconButton.filled(
                      tooltip: 'Next media',
                      onPressed: index == widget.media.length - 1
                          ? null
                          : () => navigate(index + 1),
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

  bool foreground = true, visible = true;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (!foreground) pause();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) homesRouteObserver.subscribe(this, route);
  }

  @override
  void didPushNext() {
    visible = false;
    final player = controller;
    controller = null;
    loading = false;
    player?.pause();
    player?.dispose();
    if (mounted) setState(() {});
  }

  @override
  void didPop() => pause();
  @override
  void didPopNext() {
    visible = true;
  }

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
      await player.setVolume(0);
      if (foreground && visible) await player.play();
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
    Widget retry() => Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (failed)
            const Text('Video unavailable. Try again.',
                style: TextStyle(color: Colors.white)),
          IconButton.filled(
              tooltip: failed ? 'Retry video' : 'Play video',
              onPressed: play,
              iconSize: 48,
              icon: const Icon(Icons.play_circle_outline)),
        ]));
    return ColoredBox(
        color: Colors.black,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : player == null
                ? retry()
                : ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: player,
                    builder: (_, value, __) => value.hasError
                        ? Center(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                const Text('Video unavailable. Try again.',
                                    style: TextStyle(color: Colors.white)),
                                IconButton.filled(
                                    tooltip: 'Retry video',
                                    onPressed: play,
                                    icon: const Icon(Icons.refresh)),
                              ]))
                        : Stack(fit: StackFit.expand, children: [
                            Center(
                                child: AspectRatio(
                                    aspectRatio: value.aspectRatio,
                                    child: Semantics(
                                        label: widget.label,
                                        child: VideoPlayer(player)))),
                            Positioned(
                                left: 12,
                                right: 12,
                                bottom: 8,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: .55),
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        VideoProgressIndicator(player,
                                            allowScrubbing: true,
                                            padding: const EdgeInsets.fromLTRB(
                                                12, 8, 12, 0)),
                                        Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              IconButton(
                                                  tooltip: value.volume == 0
                                                      ? 'Unmute video'
                                                      : 'Mute video',
                                                  color: Colors.white,
                                                  onPressed: () =>
                                                      player.setVolume(
                                                          value.volume == 0
                                                              ? 1
                                                              : 0),
                                                  icon: Icon(value.volume == 0
                                                      ? Icons.volume_off
                                                      : Icons.volume_up)),
                                              IconButton(
                                                  tooltip: value.isPlaying
                                                      ? 'Pause video'
                                                      : 'Play video',
                                                  color: Colors.white,
                                                  onPressed: () =>
                                                      value.isPlaying
                                                          ? player.pause()
                                                          : player.play(),
                                                  icon: Icon(value.isPlaying
                                                      ? Icons.pause
                                                      : Icons.play_arrow)),
                                            ]),
                                      ]),
                                )),
                          ])));
  }
}
