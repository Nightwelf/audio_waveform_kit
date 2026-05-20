import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:voice_message/src/controllers/audio_recording_bloc.dart';
import 'package:voice_message/src/painters/timeline_spectrum_painter.dart';

/// Offline time–frequency spectrogram.
///
/// Computed once when recording finishes. Shows how frequency content
/// evolves over time: silence → speech → loud → silence.
/// X axis = time, Y axis = frequency (low at centre, high at edges), mirrored.
class TimelineSpectrumDisplay extends StatelessWidget {
  const TimelineSpectrumDisplay({
    super.key,
    this.height = 140.0,
    this.barSpacing = 1.0,
  });

  final double height;
  final double barSpacing;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioRecordingBloc, AudioRecordingState>(
      buildWhen: (prev, curr) {
        if (curr is AudioRecordingState$Recording) return true;
        return curr is AudioRecordingState$Finished &&
            prev is! AudioRecordingState$Finished;
      },
      builder: (context, state) {
        if (state is! AudioRecordingState$Finished) {
          return SizedBox(height: height);
        }

        return SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: TimelineSpectrumPainter(
              timeline: state.spectrumTimeline,
              barSpacing: barSpacing,
            ),
          ),
        );
      },
    );
  }
}
