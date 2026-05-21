import 'package:audio_waveform_kit/src/painters/string_snapshot_painter.dart';
import 'package:flutter/material.dart';

/// Static oscilloscope view for a pre-recorded snapshot — no BLoC required.
/// Useful for voice message bubbles in chat interfaces.
class StaticStringSnapshotDisplay extends StatelessWidget {
  const StaticStringSnapshotDisplay({
    required this.samples,
    super.key,
    this.stringColor,
    this.strokeWidth = 1.5,
    this.height = 48.0,
    this.minAmplitudeFraction = 0.02,
  });

  final List<double> samples;
  final Color? stringColor;
  final double strokeWidth;
  final double height;
  final double minAmplitudeFraction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: StringSnapshotPainter(
          samples: samples,
          stringColor: stringColor ?? Theme.of(context).colorScheme.primary,
          strokeWidth: strokeWidth,
          minAmplitudeFraction: minAmplitudeFraction,
        ),
      ),
    );
  }
}
