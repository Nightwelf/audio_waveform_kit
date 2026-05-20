import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:voice_message/src/controllers/audio_recording_bloc.dart';
import 'package:voice_message/src/utils/audio_utils.dart';

class RecordingTimer extends StatelessWidget {
  const RecordingTimer({
    super.key,
    this.style,
    this.idleText = '0:00.00',
  });

  final TextStyle? style;
  final String idleText;

  static const _defaultStyle = TextStyle(
    fontFamily: 'Courier',
    fontFeatures: [FontFeature.tabularFigures()],
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioRecordingBloc, AudioRecordingState>(
      buildWhen: _buildWhen,
      builder: (context, state) {
        final text = switch (state) {
          AudioRecordingState$Recording(:final duration) =>
            AudioUtils.formatDuration(duration),
          AudioRecordingState$Finished(:final duration) =>
            AudioUtils.formatDuration(duration),
          _ => idleText,
        };

        return Text(text, style: style ?? _defaultStyle);
      },
    );
  }

  static bool _buildWhen(
    AudioRecordingState prev,
    AudioRecordingState curr,
  ) {
    if (prev.runtimeType != curr.runtimeType) return true;
    if (prev is AudioRecordingState$Recording &&
        curr is AudioRecordingState$Recording) {
      return prev.duration.inMilliseconds ~/ 10 !=
          curr.duration.inMilliseconds ~/ 10;
    }
    return false;
  }
}
