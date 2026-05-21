import 'package:audio_waveform_kit/src/controllers/audio_recording_bloc.dart';
import 'package:audio_waveform_kit/src/models/recording_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

typedef AudioRecordButtonBuilder = Widget Function({
  required BuildContext context,
  required bool isRecording,
  required VoidCallback onTap,
});

class AudioRecordButton extends StatelessWidget {
  const AudioRecordButton({
    required this.builder,
    super.key,
    this.onRecordingFinished,
  });

  /// Создаёт кнопку со стандартным круглым видом.
  factory AudioRecordButton.defaultStyle({
    Key? key,
    ValueChanged<RecordingResult>? onRecordingFinished,
    double size = 72.0,
    Color? recordingColor,
    Color? idleColor,
  }) =>
      AudioRecordButton(
        key: key,
        onRecordingFinished: onRecordingFinished,
        builder: ({required context, required isRecording, required onTap}) {
          final theme = Theme.of(context);
          final activeColor = recordingColor ?? Colors.red;
          final restColor = idleColor ?? theme.colorScheme.primary;
          final color = isRecording ? activeColor : restColor;

          return GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: isRecording ? 20 : 8,
                    spreadRadius: isRecording ? 6 : 0,
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isRecording
                    ? const Icon(
                        Icons.stop_rounded,
                        color: Colors.white,
                        size: 36,
                        key: ValueKey('stop'),
                      )
                    : const Icon(
                        Icons.mic,
                        color: Colors.white,
                        size: 36,
                        key: ValueKey('mic'),
                      ),
              ),
            ),
          );
        },
      );

  final ValueChanged<RecordingResult>? onRecordingFinished;

  /// Вызывается при каждом ребилде с текущим состоянием и колбэком нажатия.
  final AudioRecordButtonBuilder builder;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AudioRecordingBloc, AudioRecordingState>(
      listenWhen: (prev, curr) =>
          curr is AudioRecordingState$Finished &&
          prev is! AudioRecordingState$Finished,
      listener: (context, state) {
        if (state is! AudioRecordingState$Finished) return;
        onRecordingFinished?.call(
          RecordingResult(
            filePath: state.filePath,
            wavBytes: state.wavBytes,
            duration: state.duration,
            waveformSamples: state.waveformSamples,
            rmsSamples: state.rmsSamples,
            snapshotSamples: state.snapshotSamples,
            spectrumData: state.spectrumData,
            spectrumTimeline: state.spectrumTimeline,
          ),
        );
      },
      buildWhen: (prev, curr) => prev.runtimeType != curr.runtimeType,
      builder: (context, state) {
        final isRecording = state is AudioRecordingState$Recording;

        void onTap() {
          final bloc = context.read<AudioRecordingBloc>();
          if (isRecording) {
            bloc.add(const AudioRecordingEvent$Stop());
          } else {
            bloc.add(const AudioRecordingEvent$Start());
          }
        }

        return builder(
          context: context,
          isRecording: isRecording,
          onTap: onTap,
        );
      },
    );
  }
}
