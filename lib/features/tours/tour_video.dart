import '../../core/widgets/brand_loading.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'tour_backdrop.dart';

/// Inactive pages own no decoder. Generation checks reject late initialization.
class TourVideo extends StatefulWidget {
  const TourVideo(
      {super.key,
      required this.url,
      required this.active,
      required this.muted,
      this.backdropUrl,
      this.controllerFactory});
  final String url;
  final String? backdropUrl;
  final bool active, muted;
  final VideoPlayerController Function(String)? controllerFactory;
  @override
  State<TourVideo> createState() => _TourVideoState();
}

class _TourVideoState extends State<TourVideo> with WidgetsBindingObserver {
  static Future<void>? teardown;
  VideoPlayerController? player;
  Completer<void>? initializationCancelled;
  Timer? initializationTimeout;
  int generation = 0;
  bool foreground = true, paused = false, failed = false;
  Duration position = Duration.zero;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.active) start();
  }

  bool get shouldPlay => mounted && widget.active && foreground;
  @override
  void didUpdateWidget(covariant TourVideo old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      position = Duration.zero;
      paused = false;
    }
    if (old.active != widget.active || old.url != widget.url) {
      if (widget.active && foreground) {
        start();
      } else {
        release();
      }
    } else if (old.muted != widget.muted) {
      unawaited(volume());
    }
  }

  Future<void> volume() async {
    try {
      await player?.setVolume(widget.muted ? 0 : 1);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (!foreground) {
      release();
    } else if (widget.active) {
      start();
    }
  }

  Future<void> release() async {
    generation++;
    initializationTimeout?.cancel();
    initializationTimeout = null;
    final cancelled = initializationCancelled;
    initializationCancelled = null;
    if (cancelled != null && !cancelled.isCompleted) cancelled.complete();
    final old = player;
    player = null;
    if (old != null) {
      position =
          old.dataSource == widget.url ? old.value.position : Duration.zero;
      final pending = teardown;
      final next = (pending ?? Future<void>.value()).then((_) async {
        try {
          await old.pause();
        } catch (_) {}
        try {
          await old.dispose();
        } catch (_) {}
      });
      teardown = next;
      await next;
      if (identical(teardown, next)) teardown = null;
    } else {
      await teardown;
    }
  }

  Future<void> start() async {
    final releasing = release();
    final token = generation;
    await releasing;
    if (!shouldPlay || token != generation) return;
    final current = widget.controllerFactory?.call(widget.url) ??
        VideoPlayerController.networkUrl(Uri.parse(widget.url));
    player = current;
    if (mounted) setState(() => failed = false);
    try {
      final cancelled = Completer<void>();
      initializationCancelled = cancelled;
      final timer = Timer(const Duration(seconds: 20), () {
        if (!cancelled.isCompleted) {
          cancelled.completeError(
              TimeoutException('Video initialization timed out'));
        }
      });
      initializationTimeout = timer;
      try {
        await Future.any([current.initialize(), cancelled.future]);
      } finally {
        timer.cancel();
        if (identical(initializationCancelled, cancelled)) {
          initializationCancelled = null;
          initializationTimeout = null;
        }
      }
      if (!shouldPlay || token != generation || player != current) return;
      await current.setLooping(true);
      await current.setVolume(widget.muted ? 0 : 1);
      if (position > Duration.zero && position < current.value.duration)
        await current.seekTo(position);
      if (!shouldPlay || token != generation || player != current) return;
      if (!paused) await current.play();
      if (mounted && player == current) setState(() {});
    } catch (_) {
      if (mounted && player == current && token == generation) {
        await release();
        if (mounted) setState(() => failed = true);
      }
    }
  }

  Future<void> toggle() async {
    final current = player;
    if (current == null || !current.value.isInitialized) return;
    paused = !paused;
    try {
      if (paused) {
        await current.pause();
      } else if (shouldPlay) {
        await current.play();
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = player;
    Widget error() => Center(
        child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.videocam_off_outlined,
                  color: Colors.white, size: 38),
              const SizedBox(height: 12),
              const Text('This video couldn’t play.',
                  style: TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              TextButton.icon(
                  onPressed: start,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry video'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white)),
              const Text('Swipe up for another tour',
                  style: TextStyle(color: Colors.white70)),
            ])));
    final backdrop = TourBackdrop(imageUrl: widget.backdropUrl);
    if (failed)
      return Stack(fit: StackFit.expand, children: [backdrop, error()]);
    if (current == null) return backdrop;
    return Stack(fit: StackFit.expand, children: [
      backdrop,
      ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: current,
          builder: (_, value, __) {
            if (value.hasError) return error();
            if (!value.isInitialized)
              return const Center(
                  child: BrandLoading(
                      color: Colors.white, label: 'Loading property video'));
            return Stack(fit: StackFit.expand, children: [
              // Contain preserves room layouts in landscape recordings; portrait fills naturally.
              Center(
                  child: AspectRatio(
                      aspectRatio: value.aspectRatio,
                      child: VideoPlayer(current))),
              GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: toggle,
                  child: Center(
                      child: AnimatedOpacity(
                          opacity: paused ? 1 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: IconButton(
                              tooltip: paused ? 'Play tour' : 'Pause tour',
                              iconSize: 52,
                              color: Colors.white,
                              style: IconButton.styleFrom(
                                  backgroundColor: Colors.black38),
                              onPressed: toggle,
                              icon: Icon(paused
                                  ? Icons.play_arrow_rounded
                                  : Icons.pause_rounded))))),
              if (value.isBuffering)
                const Positioned(
                    top: 110,
                    left: 0,
                    right: 0,
                    child: Center(
                        child: BrandLoading(
                            color: Colors.white, label: 'Buffering tour'))),
              Positioned(
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.paddingOf(context).bottom + 8,
                  child: Semantics(
                      label: 'Video progress. Drag to seek.',
                      child: VideoProgressIndicator(current,
                          allowScrubbing: true,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          colors: const VideoProgressColors(
                              playedColor: Colors.white,
                              bufferedColor: Colors.white38,
                              backgroundColor: Colors.white24)))),
            ]);
          }),
    ]);
  }
}
