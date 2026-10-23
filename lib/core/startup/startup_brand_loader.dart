import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path_parsing/path_parsing.dart';
import 'signature_paths.dart';

/// Cold-start opening only; routing and optional account sync continue beneath it.
class StartupBrandGate extends StatefulWidget {
  const StartupBrandGate({super.key, required this.ready, required this.child});
  final Future<void> ready;
  final Widget child;
  @override
  State<StartupBrandGate> createState() => _StartupBrandGateState();
}

class _StartupBrandGateState extends State<StartupBrandGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 4080));
  bool _started = false, _ready = false, _leaving = false, _removed = false;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    void finishBootstrap() {
      if (!mounted) return;
      _ready = true;
      _leaveIfReady();
    }

    widget.ready.then((_) => finishBootstrap(),
        onError: (Object _, StackTrace __) => finishBootstrap());
    _animation.addStatusListener((_) => _leaveIfReady());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (!_started) {
      _started = true;
      _reduced = reduced;
      if (reduced) _animation.duration = const Duration(milliseconds: 150);
      _animation.forward();
    } else if (reduced && !_reduced) {
      _reduced = true;
      _animation.value = 1;
    }
  }

  void _leaveIfReady() {
    if (_ready && _animation.isCompleted && !_leaving && mounted) {
      setState(() => _leaving = true);
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      IgnorePointer(
        key: const ValueKey('startup-content'),
        ignoring: !_leaving,
        child: ExcludeSemantics(excluding: !_leaving, child: widget.child),
      ),
      if (!_removed)
        IgnorePointer(
          ignoring: _leaving,
          child: AnimatedOpacity(
            opacity: _leaving ? 0 : 1,
            duration: const Duration(milliseconds: 180),
            onEnd: () {
              if (_leaving && mounted) setState(() => _removed = true);
            },
            child: Semantics(
              label: 'Entering Homes',
              child: ColoredBox(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xff1f1e20)
                    : Colors.white,
                child: Center(
                  child: LayoutBuilder(builder: (context, constraints) {
                    final width = math.min(
                        460.0,
                        math.min(constraints.maxWidth * .8,
                            constraints.maxHeight * .8 * 684 / 700));
                    return SizedBox(
                      width: width,
                      height: width * 700 / 684,
                      child: AnimatedBuilder(
                        animation: _animation,
                        builder: (context, _) => CustomPaint(
                          painter: SignaturePainter(
                            milliseconds: _animation.value * 4080,
                            dark:
                                Theme.of(context).brightness == Brightness.dark,
                            reduced: _reduced,
                            opacity: _reduced ? _animation.value : 1,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}

class _PathReceiver implements PathProxy {
  final path = Path();
  @override
  void moveTo(double x, double y) => path.moveTo(x, y);
  @override
  void lineTo(double x, double y) => path.lineTo(x, y);
  @override
  void cubicTo(
          double x1, double y1, double x2, double y2, double x3, double y3) =>
      path.cubicTo(x1, y1, x2, y2, x3, y3);
  @override
  void close() => path.close();
}

/// SVG arcs are normalized by the existing path_parsing dependency, not traced.
class SignaturePainter extends CustomPainter {
  SignaturePainter(
      {required this.milliseconds,
      required this.dark,
      this.reduced = false,
      this.opacity = 1,
      this.markOnly = false,
      this.color});
  final double milliseconds, opacity;
  final bool dark, reduced, markOnly;
  final Color? color;
  static final _paths = signaturePaths.map((data) {
    final receiver = _PathReceiver();
    writeSvgPathDataToPath(data, receiver);
    return receiver.path;
  }).toList(growable: false);
  static final _metrics =
      _paths.map((path) => path.computeMetrics().toList()).toList();
  static const _markCurve = Cubic(.55, .05, .3, 1);
  static const _wordCurve = Cubic(.45, 0, .3, 1);
  // CSS ease-out is cubic-bezier(0,0,.58,1), not Flutter's easeOut preset.
  static const _easeOut = Cubic(0, 0, .58, 1);

  double _progress(int delay, int duration, Curve curve) => reduced
      ? 1
      : curve.transform(((milliseconds - delay) / duration).clamp(0.0, 1.0));

  void _draw(Canvas canvas, int index, Paint paint, double progress) {
    // Match pathLength=1; dasharray=1 2; dashoffset=1.02 -> 0 exactly.
    final fraction = (1 - 1.02 * (1 - progress)).clamp(0.0, 1.0);
    if (fraction <= 0) return;
    if (fraction >= 1) {
      canvas.drawPath(_paths[index], paint);
      return;
    }
    final metrics = _metrics[index];
    var remaining =
        metrics.fold<double>(0, (sum, metric) => sum + metric.length) *
            fraction;
    for (final metric in metrics) {
      if (remaining <= 0) break;
      canvas.drawPath(
          metric.extractPath(0, math.min(remaining, metric.length)), paint);
      remaining -= metric.length;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final ink =
        color ?? (dark ? const Color(0xfffafafa) : const Color(0xff222222));
    final background = dark ? const Color(0xff1f1e20) : Colors.white;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = ink
      ..strokeWidth = 48;
    canvas.save();
    if (markOnly) {
      canvas.scale(size.width / 540);
      canvas.translate(-244, -244);
    } else {
      canvas.scale(size.width / 684);
      canvas.translate(-170, -250);
    }
    canvas.saveLayer(const Rect.fromLTWH(170, 250, 684, 700),
        Paint()..color = Colors.white.withValues(alpha: opacity));
    final settle = .994 + .006 * _progress(3700, 380, _easeOut);
    canvas.translate(512, 588);
    canvas.scale(settle);
    canvas.translate(-512, -588);
    _draw(canvas, 0, paint, _progress(100, 1300, _markCurve));
    final gaps = _progress(1300, 240, _easeOut);
    if (gaps > 0) {
      if (!markOnly)
        canvas.saveLayer(const Rect.fromLTWH(170, 250, 684, 700),
            Paint()..color = Colors.white.withValues(alpha: gaps));
      paint
        ..color = background
        ..blendMode = markOnly ? BlendMode.clear : BlendMode.srcOver
        ..strokeWidth = 76;
      canvas.drawPath(_paths[1], paint);
      canvas.drawPath(_paths[2], paint);
      paint
        ..color = ink
        ..blendMode = BlendMode.srcOver
        ..strokeWidth = 48;
      canvas.drawPath(_paths[3], paint);
      canvas.drawPath(_paths[4], paint);
      if (!markOnly) canvas.restore();
    }
    canvas.save();
    canvas.translate(354, 812);
    canvas.scale(.6);
    paint.strokeWidth = 12;
    for (var i = 0; !markOnly && i < 8; i++) {
      _draw(
          canvas,
          i + 5,
          paint,
          _progress(
              signatureWordDelays[i], signatureWordDurations[i], _wordCurve));
    }
    canvas.restore();
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(SignaturePainter old) =>
      milliseconds != old.milliseconds ||
      dark != old.dark ||
      reduced != old.reduced ||
      opacity != old.opacity ||
      markOnly != old.markOnly ||
      color != old.color;
}
