import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:voice_message/src/services/audio_recording_service.dart';
import 'package:voice_message/src/utils/audio_utils.dart';
import 'package:voice_message/src/utils/file_saver.dart';

class AudioRecordingServiceImpl implements AudioRecordingService {
  AudioRecordingServiceImpl() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;
  final List<int> _pcmBytes = [];
  bool _isRecording = false;

  @override
  Future<Stream<Uint8List>> startStream() async {
    _pcmBytes.clear();
    _isRecording = true;

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        numChannels: 1,
      ),
    );

    // Tap stream to accumulate raw PCM for spectrum analysis.
    return stream.map((chunk) {
      _pcmBytes.addAll(chunk);
      return chunk;
    });
  }

  @override
  Future<String> stop() async {
    await _recorder.stop();
    _isRecording = false;

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    if (kIsWeb) {
      // Web: caller handles playback differently (blob/data URL).
      return 'vm_$timestamp';
    }

    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/vm_$timestamp.wav';
    final wavBytes = AudioUtils.encodeWav(_pcmBytes, sampleRate: 44100);
    await saveBytes(path, wavBytes);
    return path;
  }

  /// Raw PCM16LE bytes accumulated from the last recording session.
  List<int> get recordedBytes => List.unmodifiable(_pcmBytes);

  @override
  Future<void> dispose() async {
    if (_isRecording) {
      await _recorder.stop();
    }
    await _recorder.dispose();
  }
}
