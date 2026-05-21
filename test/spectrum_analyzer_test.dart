import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audio_waveform_kit/audio_waveform_kit.dart';
import 'package:flutter_test/flutter_test.dart';

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
      final result =
          analyzer.analyze(pcm, const SpectrumConfig(fftSize: fftSize));
      expect(result, hasLength(fftSize ~/ 2));
    });

    test('all-zero input yields –80 dB everywhere', () {
      const fftSize = 512;
      final pcm = List<int>.filled(fftSize * 2, 0);
      final result =
          analyzer.analyze(pcm, const SpectrumConfig(fftSize: fftSize));
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

  group('SpectrumAnalyzer.computeTimeline', () {
    test('returns empty list for input that is too short', () {
      final result = analyzer.computeTimeline([], const SpectrumConfig());
      expect(result, isEmpty);
    });

    test('returns a frames × bands matrix for a long input', () {
      const fftSize = 512;
      const bands = 24;
      const config = SpectrumConfig(fftSize: fftSize, frequencyBands: bands);
      // 10 FFT windows worth of PCM bytes.
      final pcm = List<int>.filled(fftSize * 2 * 10, 0);

      final result = analyzer.computeTimeline(pcm, config);

      expect(result, isNotEmpty);
      expect(result.every((frame) => frame.length == bands), isTrue);
    });
  });

  group('SpectrumAnalyzer.analyzeRaw', () {
    test('returns half-fftSize bins', () {
      const fftSize = 512;
      final samples = List<double>.filled(fftSize, 0);
      final result = analyzer.analyzeRaw(
        samples,
        const SpectrumConfig(fftSize: fftSize),
      );
      expect(result, hasLength(fftSize ~/ 2));
    });

    test('silence yields about -80 dB', () {
      const fftSize = 512;
      final samples = List<double>.filled(fftSize, 0);
      final result = analyzer.analyzeRaw(
        samples,
        const SpectrumConfig(fftSize: fftSize),
      );
      expect(result, everyElement(closeTo(-80, 1e-6)));
    });
  });

  group('SpectrumAnalyzer odd-length input', () {
    test('analyze does not throw on odd byte length', () {
      const fftSize = 512;
      final pcm = List<int>.filled(fftSize * 2 + 1, 0);
      expect(
        () => analyzer.analyze(pcm, const SpectrumConfig(fftSize: fftSize)),
        returnsNormally,
      );
    });

    test('computeTimeline does not throw on odd byte length', () {
      const fftSize = 512;
      final pcm = List<int>.filled(fftSize * 2 + 1, 0);
      expect(
        () => analyzer.computeTimeline(
          pcm,
          const SpectrumConfig(fftSize: fftSize),
        ),
        returnsNormally,
      );
    });
  });
}
