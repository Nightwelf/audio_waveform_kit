import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Paints messenger-style waveform bars (WhatsApp / Telegram look).
///
/// Two scaling modes controlled by the [logarithmic] field:
/// - false (default): global peak normalisation — loudest bar = full height.
/// - true: per-bar dB scaling — quiet speech stays visible.
///
/// In both modes silence is not rendered.
class MessengerWaveformPainter extends CustomPainter {
  const MessengerWaveformPainter({
    required this.samples,
    required this.barColor,
    this.barSpacing = 2.0,
    this.silenceThreshold = 0.02,
    this.logarithmic = false,
    this.minDbThreshold = -60.0,
  });

  /// RMS energy values in [0, 1] — one per time window.
  final List<double> samples;
  final Color barColor;
  final double barSpacing;

  /// Bars with normalised amplitude below this value are not rendered.
  final double silenceThreshold;

  /// true → dB scaling; false → global peak normalisation.
  final bool logarithmic;

  /// dB floor used when [logarithmic] is true (e.g. −60 dB).
  final double minDbThreshold;

  @override
  void paint(Canvas canvas, Size size) {
    final count = samples.length;
    if (count == 0) return;

    final centerY = size.height / 2;
    final cellWidth = (size.width / count).clamp(1.0, double.infinity);
    final barWidth = (cellWidth - barSpacing).clamp(1.0, double.infinity);

    final peak = logarithmic ? 0.0 : samples.fold<double>(0, math.max);
    if (!logarithmic && peak <= 0) return;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (var i = 0; i < count; i++) {
      final rms = samples[i].clamp(0.0, 1.0);

      final double normalized;
      if (logarithmic) {
        if (rms <= 0) continue;
        final db = (20 * math.log(rms) / math.ln10).clamp(minDbThreshold, 0.0);
        normalized = (db - minDbThreshold) / (-minDbThreshold);
      } else {
        normalized = rms / peak;
      }

      if (normalized < silenceThreshold) continue;

      final halfHeight = math.max(normalized * centerY, 1);
      final x = i * cellWidth + (cellWidth - barWidth) / 2;

      paint.color = barColor.withValues(alpha: 0.45 + normalized * 0.55);

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
  bool shouldRepaint(MessengerWaveformPainter oldDelegate) =>
      oldDelegate.samples != samples ||
      oldDelegate.barColor != barColor ||
      oldDelegate.logarithmic != logarithmic;
}
