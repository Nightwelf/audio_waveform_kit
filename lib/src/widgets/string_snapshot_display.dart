import 'package:audio_waveform_kit/src/controllers/audio_recording_bloc.dart';
import 'package:audio_waveform_kit/src/painters/string_snapshot_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Oscilloscope-style display: shows the shape of the audio wave
/// at the current moment — like a vibrating string, not a timeline.
class StringSnapshotDisplay extends StatelessWidget {
  const StringSnapshotDisplay({
    super.key,
    this.stringColor,
    this.strokeWidth = 1.5,
    this.height = 80.0,
    this.minAmplitudeFraction = 0.02,
  });

  final Color? stringColor;
  final double strokeWidth;
  final double height;
  final double minAmplitudeFraction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<AudioRecordingBloc, AudioRecordingState>(
      buildWhen: _buildWhen,
      builder: (context, state) {
        final snapshot = switch (state) {
          AudioRecordingState$Recording(:final snapshotSamples) =>
            snapshotSamples,
          AudioRecordingState$Finished(:final snapshotSamples) =>
            snapshotSamples,
          _ => const <double>[],
        };

        return SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: StringSnapshotPainter(
              samples: snapshot,
              stringColor: stringColor ?? theme.colorScheme.primary,
              strokeWidth: strokeWidth,
              minAmplitudeFraction: minAmplitudeFraction,
            ),
          ),
        );
      },
    );
  }

  static bool _buildWhen(
    AudioRecordingState prev,
    AudioRecordingState curr,
  ) {
    if (prev is AudioRecordingState$Recording &&
        curr is AudioRecordingState$Recording) {
      return prev.snapshotSamples != curr.snapshotSamples;
    }
    return prev.runtimeType != curr.runtimeType;
  }
}
