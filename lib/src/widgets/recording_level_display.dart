import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:voice_message/src/controllers/audio_recording_bloc.dart';
import 'package:voice_message/src/painters/recording_level_painter.dart';

/// Messenger-style amplitude bars.
///
/// Each bar height reflects the raw amplitude at that moment —
/// silence → thin bar, speech → tall bar, no cross-normalization.
class RecordingLevelDisplay extends StatelessWidget {
  const RecordingLevelDisplay({
    super.key,
    this.barColor,
    this.barSpacing = 2.0,
    this.height = 64.0,
    this.minBarHeightFraction = 0.04,
  });

  final Color? barColor;
  final double barSpacing;
  final double height;
  final double minBarHeightFraction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<AudioRecordingBloc, AudioRecordingState>(
      buildWhen: _buildWhen,
      builder: (context, state) {
        final samples = switch (state) {
          AudioRecordingState$Recording(:final waveformSamples) =>
            waveformSamples,
          AudioRecordingState$Finished(:final waveformSamples) =>
            waveformSamples,
          _ => const <double>[],
        };

        return SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: RecordingLevelPainter(
              samples: samples,
              barColor: barColor ?? theme.colorScheme.primary,
              barSpacing: barSpacing,
              minBarHeightFraction: minBarHeightFraction,
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
      return prev.waveformSamples != curr.waveformSamples;
    }
    return prev.runtimeType != curr.runtimeType;
  }
}
