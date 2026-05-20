import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voice_message/voice_message.dart';

void main() {
  late SpectrumAnalyzer analyzer;

  setUp(() => analyzer = SpectrumAnalyzer());

  group('SpectrumAnalyzer.analyze', () {
    test('returns filled list when input is too short', () {
      const config = SpectrumConfig();
      final result = analyzer.analyze([], config);
      expect(result, hasLength(config.fftSize ~/ 2));
      expect(result, everyElement(equals(-80)));
    });

    test('returns half-fftSize bins', () {
      const fftSize = 512;
      final pcm = List<int>.filled(fftSize * 2, 0);
      final result = analyzer.analyze(pcm, const SpectrumConfig(fftSize: fftSize));
      expect(result, hasLength(fftSize ~/ 2));
    });

    test('all-zero input yields –80 dB everywhere', () {
      const fftSize = 512;
      final pcm = List<int>.filled(fftSize * 2, 0);
      final result = analyzer.analyze(pcm, const SpectrumConfig(fftSize: fftSize));
      expect(result, everyElement(closeTo(-80, 1e-9)));
    });

    test('sine wave produces a peak near the expected bin', () {
      const sampleRate = 44100;
      const fftSize = 1024;
      const freq = 1000.0; // 1 kHz tone

      final byteData = ByteData(fftSize * 2);
      for (var i = 0; i < fftSize; i++) {
        final sample =
            (math.sin(2 * math.pi * freq * i / sampleRate) * 16384).round();
        byteData.setInt16(i * 2, sample, Endian.little);
      }
      final pcm = byteData.buffer.asUint8List().toList();

      final result = analyzer.analyze(
        pcm,
        const SpectrumConfig(),
      );

      // Expected bin ≈ freq * fftSize / sampleRate ≈ 23
      final expectedBin = (freq * fftSize / sampleRate).round();
      final peakBin = result.indexWhere((v) => v == result.reduce(math.max));

      expect((peakBin - expectedBin).abs(), lessThanOrEqualTo(2));
    });
  });

  group('SpectrumAnalyzer.toLogScale', () {
    test('returns correct number of bands', () {
      const config = SpectrumConfig(frequencyBands: 32);
      final spectrum = List<double>.filled(512, -40);
      final result = analyzer.toLogScale(spectrum, config);
      expect(result, hasLength(32));
    });
  });
}
