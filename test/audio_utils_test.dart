import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voice_message/voice_message.dart';

void main() {
  group('AudioUtils.encodeWav', () {
    test('produces a 44-byte header + data', () {
      const sampleRate = 44100;
      final pcm = List<int>.filled(100, 0);
      final wav = AudioUtils.encodeWav(pcm, sampleRate: sampleRate);

      expect(wav.length, equals(44 + pcm.length));
    });

    test('RIFF header is correct', () {
      final wav = AudioUtils.encodeWav([0, 0], sampleRate: 44100);
      expect(wav.sublist(0, 4), equals([0x52, 0x49, 0x46, 0x46])); // RIFF
      expect(wav.sublist(8, 12), equals([0x57, 0x41, 0x56, 0x45])); // WAVE
    });

    test('round-trip encodeWav → wavToSamples', () {
      final byteData = ByteData(8)
        ..setInt16(0, 0, Endian.little)
        ..setInt16(2, 16384, Endian.little)
        ..setInt16(4, -16384, Endian.little)
        ..setInt16(6, 32767, Endian.little);
      final pcm = byteData.buffer.asUint8List().toList();

      final wav = AudioUtils.encodeWav(pcm, sampleRate: 44100);
      final samples = AudioUtils.wavToSamples(wav);

      expect(samples, hasLength(4));
      expect(samples[0], closeTo(0, 0.0001));
      expect(samples[1], closeTo(0.5, 0.01));
      expect(samples[2], closeTo(-0.5, 0.01));
    });
  });

  group('AudioUtils.formatDuration', () {
    test('formats zero', () {
      expect(AudioUtils.formatDuration(Duration.zero), equals('0:00.00'));
    });

    test('formats 1m 5s 300ms', () {
      expect(
        AudioUtils.formatDuration(
          const Duration(minutes: 1, seconds: 5, milliseconds: 300),
        ),
        equals('1:05.30'),
      );
    });
  });
}
