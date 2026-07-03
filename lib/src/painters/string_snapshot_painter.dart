import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Draws a snapshot of raw PCM samples as a smooth oscilloscope curve —
/// like a vibrating string frozen at one moment in time.
class StringSnapshotPainter extends CustomPainter {
  StringSnapshotPainter({
    required this.samples,
    required this.stringColor,
    this.strokeWidth = 1.5,
    this.minAmplitudeFraction = 0.02,
  });

  final List<double> samples;
  final Color stringColor;
  final double strokeWidth;

  /// If peak amplitude is below this fraction of max, show a resting string
  /// instead of amplifying noise.
  final double minAmplitudeFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;

    // Меньше 2 точек — путь через квадратичные кривые не строится
    // (stepX делится на count - 1), рисуем состояние покоя.
    if (samples.length < 2) {
      _drawRestingString(canvas, size, centerY);
      return;
    }

    final peak = samples.fold<double>(0, (m, s) => math.max(m, s.abs()));

    if (peak < minAmplitudeFraction) {
      _drawRestingString(canvas, size, centerY);
      return;
    }

    final scale = 1.0 / peak;
    final path = _buildSmoothedPath(size, centerY, scale);

    canvas
      ..drawPath(
        path,
        Paint()
          ..color = stringColor.withValues(alpha: 0.25)
          ..strokeWidth = strokeWidth * 5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
          ..isAntiAlias = true,
      )
      ..drawPath(
        path,
        Paint()
          ..color = stringColor
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true,
      );
  }

  Path _buildSmoothedPath(Size size, double centerY, double scale) {
    final count = samples.length;
    final stepX = size.width / (count - 1);

    final path = Path();
    final firstY = centerY - samples[0] * scale * centerY;
    path.moveTo(0, firstY);

    // Quadratic bezier through midpoints — gives smooth "string" curve
    for (var i = 1; i < count - 1; i++) {
      final x0 = (i - 1) * stepX;
      final y0 = centerY - samples[i - 1] * scale * centerY;
      final x1 = i * stepX;
      final y1 = centerY - samples[i] * scale * centerY;
      final midX = (x0 + x1) / 2;
      final midY = (y0 + y1) / 2;
      path.quadraticBezierTo(x0, y0, midX, midY);
    }

    final lastX = (count - 1) * stepX;
    final lastY = centerY - samples[count - 1] * scale * centerY;
    path.lineTo(lastX, lastY);

    return path;
  }

  void _drawRestingString(Canvas canvas, Size size, double centerY) {
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      Paint()
        ..color = stringColor.withValues(alpha: 0.4)
        ..strokeWidth = strokeWidth
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(StringSnapshotPainter oldDelegate) =>
      oldDelegate.samples != samples || oldDelegate.stringColor != stringColor;
}
