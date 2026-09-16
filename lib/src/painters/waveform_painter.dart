import 'package:audio_waveform_kit/src/utils/level_scale.dart';
import 'package:flutter/material.dart';

enum WaveformStyle { envelope, string }

/// Draws an RMS envelope. `WaveformStyle.string` is handled at the widget
/// level by `WaveformDisplay` rendering `StringSnapshotDisplay` instead —
/// this painter only ever draws the envelope.
class WaveformPainter extends CustomPainter {
  WaveformPainter({
    required this.samples,
    required this.waveColor,
    required this.baselineColor,
    this.strokeWidth = 2.0,
    this.floorDb = -55.0,
    this.ceilingDb = -15.0,
  });

  /// RMS energy per window (non-negative).
  final List<double> samples;
  final Color waveColor;
  final Color baselineColor;
  final double strokeWidth;

  /// Signal level (dBFS RMS) at which the envelope lies flat.
  final double floorDb;

  /// Signal level (dBFS RMS) at which the envelope fills the box.
  final double ceilingDb;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;

    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      Paint()
        ..color = baselineColor
        ..strokeWidth = 1,
    );

    if (samples.isEmpty) return;

    final step = size.width / samples.length;
    final path = Path();

    for (var i = 0; i < samples.length; i++) {
      final x = i * step;
      final amp =
          amplitudeForRms(samples[i], floorDb: floorDb, ceilingDb: ceilingDb);
      final y = centerY - amp * centerY;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    for (var i = samples.length - 1; i >= 0; i--) {
      final x = i * step;
      final amp =
          amplitudeForRms(samples[i], floorDb: floorDb, ceilingDb: ceilingDb);
      final y = centerY + amp * centerY;
      path.lineTo(x, y);
    }

    path.close();

    canvas
      ..drawPath(
        path,
        Paint()
          ..color = waveColor.withValues(alpha: 0.25)
          ..style = PaintingStyle.fill,
      )
      ..drawPath(
        path,
        Paint()
          ..color = waveColor
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true,
      );
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) =>
      oldDelegate.samples != samples ||
      oldDelegate.waveColor != waveColor ||
      oldDelegate.baselineColor != baselineColor ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.floorDb != floorDb ||
      oldDelegate.ceilingDb != ceilingDb;
}
