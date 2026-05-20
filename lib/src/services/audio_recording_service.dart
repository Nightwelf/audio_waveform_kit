import 'dart:typed_data';

abstract class AudioRecordingService {
  Future<Stream<Uint8List>> startStream();

  /// Stops recording. Returns the saved WAV file path (or key on web).
  Future<String> stop();

  Future<void> dispose();
}
