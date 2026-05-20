import 'dart:math' as math;

import 'package:flutter/material.dart';

class LogarithmicSpectrumPainter extends CustomPainter {
  LogarithmicSpectrumPainter({
    required this.spectrum,
    required this.baseColor,
    this.minDb = -80.0,
    this.maxDb = 0.0,
    this.frequencyMin = 20.0,
    this.frequencyMax = 20000.0,
    this.bands = 64,
    this.barSpacing = 1.0,
  });

  final List<double> spectrum;
  final Color baseColor;
  final double minDb;
  final double maxDb;
  final double frequencyMin;
  final double frequencyMax;
  final int bands;
  final double barSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    if (spectrum.isEmpty) return;

    final barWidth =
        ((size.width - barSpacing * (bands - 1)) / bands).clamp(1.0, double.infinity);
    final range = maxDb - minDb;
    final centerY = size.height / 2;

    for (var band = 0; band < bands; band++) {
      final t = bands > 1 ? band / (bands - 1) : 0.0;
      final logFreq =
          frequencyMin * math.pow(frequencyMax / frequencyMin, t);
      final binIdx =
          ((logFreq / (frequencyMax / 2)) * spectrum.length)
              .round()
              .clamp(0, spectrum.length - 1);

      final normalized = ((spectrum[binIdx] - minDb) / range).clamp(0.0, 1.0);
      final halfHeight = normalized * centerY;
      if (halfHeight < 1) continue;

      final x = band * (barWidth + barSpacing);

      // Hue: low freq = warm, high freq = cool
      final hue = (1 - t) * 30 + t * 220;
      final color = HSVColor.fromAHSV(
        1,
        hue,
        0.75,
        0.5 + normalized * 0.5,
      ).toColor();

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, centerY - halfHeight, barWidth, halfHeight * 2),
          const Radius.circular(2),
        ),
        Paint()
          ..color = color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
    }
  }

  @override
  bool shouldRepaint(LogarithmicSpectrumPainter oldDelegate) =>
      oldDelegate.spectrum != spectrum;
}
