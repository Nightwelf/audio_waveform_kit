import 'dart:typed_data';

import 'package:audio_waveform_kit/src/services/audio_recording_service.dart';
import 'package:audio_waveform_kit/src/utils/audio_utils.dart';
import 'package:audio_waveform_kit/src/utils/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioRecordingServiceImpl implements AudioRecordingService {
  AudioRecordingServiceImpl({this.sampleRate = 44100})
      : _recorder = AudioRecorder();

  final int sampleRate;
  final AudioRecorder _recorder;
  final BytesBuilder _pcmBuilder = BytesBuilder(copy: false);
  bool _isRecording = false;

  @override
  Future<Stream<Uint8List>> startStream() async {
    _pcmBuilder.clear();
    _isRecording = true;

    final stream = await _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        numChannels: 1,
        sampleRate: sampleRate,
      ),
    );

    // Tap stream to accumulate raw PCM for spectrum analysis.
    return stream.map((chunk) {
      _pcmBuilder.add(chunk);
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
    final wavBytes = AudioUtils.encodeWav(
      _pcmBuilder.toBytes(),
      sampleRate: sampleRate,
    );
    await saveBytes(path, wavBytes);
    return path;
  }

  @override
  Uint8List get recordedBytes => _pcmBuilder.toBytes();

  @override
  Future<void> dispose() async {
    if (_isRecording) {
      await _recorder.stop();
    }
    await _recorder.dispose();
  }
}
