import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/zullo_palette.dart';
import 'zullo_symbol.dart';

/// Decorative discovery motion; never implies an outstanding network request.
class DiscoverySearchMark extends StatefulWidget {
  const DiscoverySearchMark(
      {super.key,
      required this.size,
      this.paused = false,
      this.animate = true});
  final double size;
  final bool paused, animate;
  @override
  State<DiscoverySearchMark> createState() => _DiscoverySearchMarkState();
}

class _DiscoverySearchMarkState extends State<DiscoverySearchMark>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _progress = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600));
  bool _foreground = true, _motionAllowed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motionAllowed = TickerMode.of(context) &&
        !MediaQuery.disableAnimationsOf(context) &&
        !MediaQuery.accessibleNavigationOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(covariant DiscoverySearchMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    if (_foreground && _motionAllowed && widget.animate && !widget.paused) {
      if (!_progress.isAnimating) _progress.repeat();
    } else {
      _progress.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
          child: RepaintBoundary(
        child: SizedBox.square(
            dimension: widget.size,
            child: CustomPaint(
              painter: _DiscoveryRings(_progress,
                  paused: widget.paused,
                  moving: _foreground && _motionAllowed && widget.animate),
              child: Center(
                  child: Container(
                width: widget.size * .64,
                height: widget.size * .64,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: Center(
                    child: widget.paused
                        ? const Icon(Icons.pause_rounded,
                            size: 40, color: ZulloPalette.rose)
                        : const ZulloSymbol(
                            kind: ZulloSymbolKind.discover,
                            color: ZulloPalette.rose,
                            size: 40)),
              )),
            )),
      ));
}

class _DiscoveryRings extends CustomPainter {
  _DiscoveryRings(this.progress, {required this.paused, required this.moving})
      : super(repaint: progress);
  final Animation<double> progress;
  final bool paused, moving;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero), radius = size.shortestSide / 2;
    final phase = moving && !paused ? progress.value : 0.0;
    canvas.drawCircle(
        center,
        radius * .98,
        Paint()
          ..shader = const RadialGradient(
                  colors: [Color(0xFFFFD7E8), Color(0xFFFFFAFC)])
              .createShader(Offset.zero & size));
    if (!paused) {
      for (var i = 0; i < 2; i++) {
        final wave = (phase + i / 2) % 1;
        canvas.drawCircle(
            center,
            radius * (.64 + .34 * wave),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = ZulloPalette.rose.withValues(alpha: .19 * (1 - wave)));
      }
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(phase * math.pi * 2);
      final rect = Rect.fromCircle(center: Offset.zero, radius: radius * .96);
      canvas.drawCircle(
          Offset.zero,
          radius * .96,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..shader = const SweepGradient(colors: [
              Color(0x00EC2863),
              Color(0x18EC2863),
              Color(0xA0EC2863),
              Color(0x00EC2863)
            ], stops: [
              0,
              .5,
              .9,
              1
            ]).createShader(rect));
      canvas.restore();
    } else {
      canvas.drawCircle(
          center,
          radius * .95,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = const Color(0xFFE8EBF0));
    }
  }

  @override
  bool shouldRepaint(covariant _DiscoveryRings old) =>
      old.paused != paused || old.moving != moving;
}
