import 'dart:math' as math;
import 'package:flutter/material.dart';

enum ZulloSymbolKind { discover, conversation }

/// Small vector marks drawn at their final size; no asset or image decoding.
class ZulloSymbol extends StatelessWidget {
  final ZulloSymbolKind kind;
  final Color color;
  final double size;
  const ZulloSymbol(
      {super.key, required this.kind, required this.color, this.size = 26});
  @override
  Widget build(BuildContext context) => SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SymbolPainter(kind, color)));
}

class _SymbolPainter extends CustomPainter {
  final ZulloSymbolKind kind;
  final Color color;
  const _SymbolPainter(this.kind, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 28, size.height / 28);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (kind == ZulloSymbolKind.discover) {
      canvas.drawArc(const Rect.fromLTWH(3, 3, 22, 22), -.35, math.pi * 1.55,
          false, stroke);
      canvas.drawPath(
          Path()
            ..moveTo(10, 9)
            ..lineTo(19, 9)
            ..lineTo(9, 19)
            ..lineTo(18, 19),
          stroke);
      canvas.drawCircle(const Offset(24, 5), 2.1, Paint()..color = color);
    } else {
      canvas.drawPath(
          Path()
            ..moveTo(8, 4)
            ..lineTo(21, 4)
            ..quadraticBezierTo(25, 4, 25, 8)
            ..lineTo(25, 17)
            ..quadraticBezierTo(25, 21, 21, 21)
            ..lineTo(12, 21)
            ..lineTo(6, 25)
            ..lineTo(6, 20)
            ..quadraticBezierTo(3, 19, 3, 16)
            ..lineTo(3, 9)
            ..quadraticBezierTo(3, 4, 8, 4),
          stroke);
      canvas.drawLine(const Offset(9, 10), const Offset(19, 10), stroke);
      canvas.drawLine(const Offset(9, 15), const Offset(16, 15), stroke);
    }
  }

  @override
  bool shouldRepaint(_SymbolPainter old) =>
      kind != old.kind || color != old.color;
}
