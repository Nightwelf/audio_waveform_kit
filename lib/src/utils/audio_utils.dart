import 'dart:typed_data';

import 'package:audio_waveform_kit/src/constants.dart';

abstract class AudioUtils {
  AudioUtils._();

  /// Wraps raw PCM16LE mono bytes in a WAV container.
  static Uint8List encodeWav(
    List<int> pcmBytes, {
    required int sampleRate,
    int numChannels = 1,
    int bitsPerSample = 16,
  }) {
    final dataSize = pcmBytes.length;
    final buffer = ByteData(44 + dataSize)
      // RIFF chunk
      ..setUint8(0, 0x52) // R
      ..setUint8(1, 0x49) // I
      ..setUint8(2, 0x46) // F
      ..setUint8(3, 0x46) // F
      ..setUint32(4, 36 + dataSize, Endian.little)
      ..setUint8(8, 0x57) // W
      ..setUint8(9, 0x41) // A
      ..setUint8(10, 0x56) // V
      ..setUint8(11, 0x45) // E
      // fmt chunk
      ..setUint8(12, 0x66) // f
      ..setUint8(13, 0x6D) // m
      ..setUint8(14, 0x74) // t
      ..setUint8(15, 0x20) // space
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little) // PCM
      ..setUint16(22, numChannels, Endian.little)
      ..setUint32(24, sampleRate, Endian.little)
      ..setUint32(
        28,
        sampleRate * numChannels * bitsPerSample ~/ 8,
        Endian.little,
      )
      ..setUint16(32, numChannels * bitsPerSample ~/ 8, Endian.little)
      ..setUint16(34, bitsPerSample, Endian.little)
      // data chunk
      ..setUint8(36, 0x64) // d
      ..setUint8(37, 0x61) // a
      ..setUint8(38, 0x74) // t
      ..setUint8(39, 0x61) // a
      ..setUint32(40, dataSize, Endian.little);

    for (var i = 0; i < dataSize; i++) {
      buffer.setUint8(44 + i, pcmBytes[i]);
    }

    return buffer.buffer.asUint8List();
  }

  /// Reads raw PCM16LE samples from WAV bytes, skipping the 44-byte header.
  static List<double> wavToSamples(Uint8List wavBytes) {
    if (wavBytes.length < 44) return [];
    final int16View = wavBytes.buffer.asInt16List(44);
    return List.generate(int16View.length, (i) => int16View[i] / kInt16Scale);
  }

  static String formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final centiseconds = (duration.inMilliseconds % 1000) ~/ 10;
    return '$minutes:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${centiseconds.toString().padLeft(2, '0')}';
  }
}
