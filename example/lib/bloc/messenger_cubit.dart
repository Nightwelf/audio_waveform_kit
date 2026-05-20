import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:voice_message/voice_message.dart';

class VoiceNote {
  const VoiceNote({
    required this.filePath,
    required this.duration,
    required this.waveformSamples,
    required this.snapshotSamples,
  });

  final String filePath;
  final Duration duration;
  final List<double> waveformSamples;
  final List<double> snapshotSamples;
}

class MessengerCubit extends Cubit<List<VoiceNote>> {
  MessengerCubit() : super(const []);

  void addFromState(AudioRecordingState$Finished state) => emit([
        ...this.state,
        VoiceNote(
          filePath: state.filePath,
          duration: state.duration,
          waveformSamples: state.waveformSamples,
          snapshotSamples: state.snapshotSamples,
        ),
      ]);
}
