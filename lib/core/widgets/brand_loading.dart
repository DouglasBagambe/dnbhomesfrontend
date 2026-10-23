import 'package:flutter/material.dart';
import '../startup/startup_brand_loader.dart';

/// A quiet draw, hold and fade loop of the approved symbol, without the wordmark.
class BrandLoading extends StatefulWidget {
  const BrandLoading(
      {super.key, this.size = 52, this.color, this.label = 'Loading'});
  final double size;
  final Color? color;
  final String label;
  @override
  State<BrandLoading> createState() => _BrandLoadingState();
}

class _BrandLoadingState extends State<BrandLoading>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3200));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.stop();
      controller.value = .7;
    } else if (!controller.isAnimating) {
      controller.repeat();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
      label: widget.label,
      child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final t = controller.value;
                final opacity =
                    t < .8 ? 1.0 : (1 - (t - .8) / .2).clamp(0.0, 1.0);
                return CustomPaint(
                    painter: SignaturePainter(
                        milliseconds: t * 3200,
                        dark: Theme.of(context).brightness == Brightness.dark,
                        markOnly: true,
                        color: widget.color ??
                            Theme.of(context).colorScheme.primary,
                        opacity: opacity));
              })));
}

/// Keep pull-to-refresh gestures while replacing Material's rotating indicator.
class BrandRefreshIndicator extends StatefulWidget {
  const BrandRefreshIndicator(
      {super.key, required this.onRefresh, required this.child});
  final Future<void> Function() onRefresh;
  final Widget child;
  @override
  State<BrandRefreshIndicator> createState() => _BrandRefreshIndicatorState();
}

class _BrandRefreshIndicatorState extends State<BrandRefreshIndicator> {
  RefreshIndicatorStatus? status;
  @override
  Widget build(BuildContext context) => Stack(children: [
        RefreshIndicator.noSpinner(
            onRefresh: () async {
              if (mounted)
                setState(() => status = RefreshIndicatorStatus.refresh);
              try {
                await widget.onRefresh();
              } finally {
                if (mounted)
                  setState(() => status = RefreshIndicatorStatus.done);
              }
            },
            onStatusChange: (value) {
              if (mounted) setState(() => status = value);
            },
            child: widget.child),
        if (status != null &&
            status != RefreshIndicatorStatus.done &&
            status != RefreshIndicatorStatus.canceled)
          Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: IgnorePointer(
                  child: Center(
                      child: Material(
                          elevation: 2,
                          shape: const CircleBorder(),
                          color: Theme.of(context).colorScheme.surface,
                          child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: status == RefreshIndicatorStatus.refresh
                                  ? const BrandLoading(
                                      size: 30, label: 'Refreshing')
                                  : Icon(Icons.arrow_downward_rounded,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary))))))
      ]);
}
