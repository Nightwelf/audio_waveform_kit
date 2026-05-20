import 'package:flutter/material.dart';

class SpectrumPainter extends CustomPainter {
  SpectrumPainter({
    required this.spectrum,
    required this.barColor,
    this.minDb = -80.0,
    this.maxDb = 0.0,
    this.barSpacing = 1.0,
  });

  final List<double> spectrum;
  final Color barColor;
  final double minDb;
  final double maxDb;
  final double barSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    if (spectrum.isEmpty) return;

    final count = spectrum.length;
    final barWidth =
        ((size.width - barSpacing * (count - 1)) / count).clamp(1.0, double.infinity);
    final range = maxDb - minDb;

    final paint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final centerY = size.height / 2;

    for (var i = 0; i < count; i++) {
      final normalized = ((spectrum[i] - minDb) / range).clamp(0.0, 1.0);
      final halfHeight = normalized * centerY;
      if (halfHeight < 1) continue;

      final x = i * (barWidth + barSpacing);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, centerY - halfHeight, barWidth, halfHeight * 2),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(SpectrumPainter oldDelegate) =>
      oldDelegate.spectrum != spectrum || oldDelegate.barColor != barColor;
}
