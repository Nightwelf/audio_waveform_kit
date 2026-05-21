import 'dart:math' as math;

import 'package:audio_waveform_kit/src/widgets/waveform_display.dart';
import 'package:flutter/material.dart';

class WaveformPainter extends CustomPainter {
  WaveformPainter({
    required this.samples,
    required this.waveColor,
    required this.baselineColor,
    this.strokeWidth = 2.0,
    this.style = WaveformStyle.envelope,
  });

  final List<double> samples;
  final Color waveColor;
  final Color baselineColor;
  final double strokeWidth;
  final WaveformStyle style;

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

    // Normalize: find peak absolute value, scale so max fills the display.
    // If recording is very quiet (peak < 0.01), don't amplify noise.
    final peak = samples.fold<double>(0, (m, s) => math.max(m, s.abs()));
    final scale = peak > 0.01 ? 1.0 / peak : 1.0;

    switch (style) {
      case WaveformStyle.envelope:
        _paintEnvelope(canvas, size, centerY, scale);
      case WaveformStyle.string:
        _paintString(canvas, size, centerY, scale);
    }
  }

  void _paintEnvelope(
    Canvas canvas,
    Size size,
    double centerY,
    double scale,
  ) {
    final step = size.width / samples.length;
    final path = Path();

    for (var i = 0; i < samples.length; i++) {
      final x = i * step;
      final amp = (samples[i].abs() * scale).clamp(0.0, 1.0);
      final y = centerY - amp * centerY;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    for (var i = samples.length - 1; i >= 0; i--) {
      final x = i * step;
      final amp = (samples[i].abs() * scale).clamp(0.0, 1.0);
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

  void _paintString(
    Canvas canvas,
    Size size,
    double centerY,
    double scale,
  ) {
    final step = size.width / samples.length;

    final path = Path();
    for (var i = 0; i < samples.length; i++) {
      final x = i * step;
      final y = centerY - (samples[i] * scale).clamp(-1.0, 1.0) * centerY;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas
      // Glow layer
      ..drawPath(
        path,
        Paint()
          ..color = waveColor.withValues(alpha: 0.2)
          ..strokeWidth = strokeWidth * 4
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
          ..isAntiAlias = true,
      )
      // Core line
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
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.style != style;
}
