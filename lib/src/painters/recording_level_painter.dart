import 'dart:math' as math;

import 'package:audio_waveform_kit/src/utils/level_scale.dart';
import 'package:flutter/material.dart';

class RecordingLevelPainter extends CustomPainter {
  RecordingLevelPainter({
    required this.samples,
    required this.barColor,
    this.barSpacing = 2.0,
    this.minBarHeightFraction = 0.04,
    this.floorDb = -55.0,
    this.ceilingDb = -15.0,
  });

  /// RMS energy per window (non-negative), one value per bar.
  final List<double> samples;
  final Color barColor;
  final double barSpacing;

  /// Minimum bar half-height as a fraction of the available half-height.
  /// Keeps silence visually alive (thin line instead of nothing).
  final double minBarHeightFraction;

  /// Signal level (dBFS RMS) at which a bar is minimal — anything quieter
  /// is silence.
  final double floorDb;

  /// Signal level (dBFS RMS) at which a bar reaches full height.
  final double ceilingDb;

  @override
  void paint(Canvas canvas, Size size) {
    final count = samples.length;
    if (count == 0) return;

    final centerY = size.height / 2;
    final minHalfHeight = minBarHeightFraction * centerY;
    final barWidth = ((size.width - barSpacing * (count - 1)) / count)
        .clamp(1.0, double.infinity);

    for (var i = 0; i < count; i++) {
      final amp =
          amplitudeForRms(samples[i], floorDb: floorDb, ceilingDb: ceilingDb);
      final halfHeight = math.max(amp * centerY, minHalfHeight);
      final x = i * (barWidth + barSpacing);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, centerY - halfHeight, barWidth, halfHeight * 2),
          const Radius.circular(2),
        ),
        Paint()
          ..color = barColor.withValues(alpha: 0.3 + amp * 0.7)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
    }
  }

  @override
  bool shouldRepaint(RecordingLevelPainter oldDelegate) =>
      oldDelegate.samples != samples ||
      oldDelegate.barColor != barColor ||
      oldDelegate.barSpacing != barSpacing ||
      oldDelegate.minBarHeightFraction != minBarHeightFraction ||
      oldDelegate.floorDb != floorDb ||
      oldDelegate.ceilingDb != ceilingDb;
}
