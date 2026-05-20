import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Paints a timeline of frequency energy as vertical bars — one bar per time frame.
///
/// Bar height = aggregate energy at that moment (silence → flat, loud → tall).
/// Bar colour = spectral centroid (dominant frequency: warm = low, cool = high).
/// Mirrored vertically from the centre, rounded corners — same style as SpectrumPainter.
class TimelineSpectrumPainter extends CustomPainter {
  TimelineSpectrumPainter({
    required this.timeline,
    this.barSpacing = 1.0,
  });

  /// [frames × bands] matrix of linear magnitudes.
  final List<List<double>> timeline;
  final double barSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    final frames = timeline.length;
    if (frames == 0) return;
    final bands = timeline[0].length;
    if (bands == 0) return;

    final centerY = size.height / 2;
    final barWidth =
        ((size.width - barSpacing * (frames - 1)) / frames).clamp(1.0, double.infinity);

    // Pre-compute per-frame aggregate energy and spectral centroid.
    final energies = List<double>.filled(frames, 0);
    final centroids = List<double>.filled(frames, 0);

    for (var t = 0; t < frames; t++) {
      final frame = timeline[t];
      var sum = 0.0;
      var weightedSum = 0.0;
      for (var b = 0; b < bands; b++) {
        sum += frame[b];
        weightedSum += b * frame[b];
      }
      energies[t] = sum / bands;
      centroids[t] = sum > 0 ? weightedSum / sum : 0;
    }

    // Normalise by global peak energy so the loudest frame = full height.
    final peak = energies.fold<double>(0, math.max);
    if (peak <= 0) return;

    for (var t = 0; t < frames; t++) {
      final normalized = (energies[t] / peak).clamp(0.0, 1.0);
      final halfHeight = normalized * centerY;
      if (halfHeight < 1) continue;

      final x = t * (barWidth + barSpacing);

      // Hue from spectral centroid: low freq (0) → warm 30°, high freq → cool 220°.
      final freqT = centroids[t] / (bands - 1);
      final hue = (1 - freqT) * 30 + freqT * 220;
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
  bool shouldRepaint(TimelineSpectrumPainter oldDelegate) =>
      oldDelegate.timeline != timeline;
}
