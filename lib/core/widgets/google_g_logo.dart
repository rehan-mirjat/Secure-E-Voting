import 'package:flutter/material.dart';

class GoogleGLogo extends StatelessWidget {
  final double size;

  const GoogleGLogo({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleGLogoPainter(),
      ),
    );
  }
}

class _GoogleGLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final Offset center = Offset(radius, radius);
    final double strokeWidth = size.width * 0.22;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square;

    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    // 1. Red Arc (Top)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -0.7, -1.8, false, paint);

    // 2. Yellow Arc (Bottom-Left)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 1.2, 1.3, false, paint);

    // 3. Green Arc (Bottom-Right)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.2, 1.1, false, paint);

    // 4. Blue Arc & Crossbar (Right)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.7, 1.0, false, paint);

    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    final barRect = Rect.fromLTRB(
      center.dx,
      center.dy - strokeWidth / 2,
      center.dx + radius - strokeWidth / 4,
      center.dy + strokeWidth / 2,
    );
    canvas.drawRect(barRect, barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
