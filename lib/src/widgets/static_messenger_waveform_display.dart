import 'package:flutter/material.dart';
import 'package:voice_message/src/painters/messenger_waveform_painter.dart';

/// Static messenger-style waveform — no BLoC, takes pre-recorded [samples].
///
/// Intended for the post-recording "final result" view —
/// same role as StaticLevelDisplay but with messenger visual style and RMS input.
///
/// Two scaling modes via [logarithmic]:
/// - false (default): global peak normalisation (WhatsApp / Telegram bubble look).
/// - true: dB scaling (quiet speech stays visible).
class StaticMessengerWaveformDisplay extends StatelessWidget {
  const StaticMessengerWaveformDisplay({
    required this.samples,
    super.key,
    this.height = 48.0,
    this.barColor,
    this.barSpacing = 2.0,
    this.silenceThreshold = 0.02,
    this.logarithmic = false,
    this.minDbThreshold = -60.0,
  });

  final List<double> samples;
  final double height;
  final Color? barColor;
  final double barSpacing;
  final double silenceThreshold;
  final bool logarithmic;
  final double minDbThreshold;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: MessengerWaveformPainter(
          samples: samples,
          barColor: barColor ?? Theme.of(context).colorScheme.primary,
          barSpacing: barSpacing,
          silenceThreshold: silenceThreshold,
          logarithmic: logarithmic,
          minDbThreshold: minDbThreshold,
        ),
      ),
    );
  }
}
