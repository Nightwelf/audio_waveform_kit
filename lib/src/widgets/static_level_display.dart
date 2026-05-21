import 'package:audio_waveform_kit/src/painters/recording_level_painter.dart';
import 'package:flutter/material.dart';

/// Draws amplitude bars for a pre-recorded [samples] list — no BLoC required.
/// Useful for voice message bubbles in chat interfaces.
class StaticLevelDisplay extends StatelessWidget {
  const StaticLevelDisplay({
    required this.samples,
    super.key,
    this.barColor,
    this.barSpacing = 2.0,
    this.height = 40.0,
    this.minBarHeightFraction = 0.15,
  });

  final List<double> samples;
  final Color? barColor;
  final double barSpacing;
  final double height;
  final double minBarHeightFraction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: RecordingLevelPainter(
          samples: samples,
          barColor: barColor ?? Theme.of(context).colorScheme.primary,
          barSpacing: barSpacing,
          minBarHeightFraction: minBarHeightFraction,
        ),
      ),
    );
  }
}
