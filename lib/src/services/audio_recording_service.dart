import 'dart:typed_data';

abstract class AudioRecordingService {
  Future<Stream<Uint8List>> startStream();

  /// Stops recording. Returns the saved WAV file path (or key on web).
  Future<String> stop();

  /// Raw PCM16LE bytes accumulated from the last recording session.
  Uint8List get recordedBytes;

  Future<void> dispose();
}
