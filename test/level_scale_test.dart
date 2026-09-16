import 'package:audio_waveform_kit/src/utils/level_scale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('amplitudeForRms', () {
    test('тишина — 0', () {
      expect(amplitudeForRms(0, floorDb: -55, ceilingDb: -15), 0);
      expect(amplitudeForRms(-1, floorDb: -55, ceilingDb: -15), 0);
    });

    test('шум комнаты дрожит, но не размахивается', () {
      // RMS постоянного сигнала равен его значению: 0.00316 ≈ −50 dBFS.
      final noise = amplitudeForRms(0.00316, floorDb: -55, ceilingDb: -15);

      expect(noise, greaterThan(0));
      expect(noise, lessThan(0.2));
    });

    test('речь занимает большую часть бокса', () {
      // 0.0562 ≈ −25 dBFS.
      expect(
        amplitudeForRms(0.0562, floorDb: -55, ceilingDb: -15),
        closeTo(0.75, 0.02),
      );
    });

    test('монотонность: громче — всегда больше', () {
      expect(
        amplitudeForRms(0.0562, floorDb: -55, ceilingDb: -15),
        greaterThan(amplitudeForRms(0.00316, floorDb: -55, ceilingDb: -15)),
      );
      expect(
        amplitudeForRms(0.00316, floorDb: -55, ceilingDb: -15),
        greaterThan(amplitudeForRms(0.001, floorDb: -55, ceilingDb: -15)),
      );
    });

    test('клампы на полу и потолке', () {
      expect(amplitudeForRms(1e-9, floorDb: -55, ceilingDb: -15), 0);
      expect(amplitudeForRms(0.5, floorDb: -55, ceilingDb: -15), 1.0);
    });

    test('вырожденный диапазон floorDb == ceilingDb не даёт NaN', () {
      final a = amplitudeForRms(0.05, floorDb: -20, ceilingDb: -20);

      expect(a.isNaN, isFalse);
    });
  });

  group('rmsOf', () {
    test('пустой список — 0', () {
      expect(rmsOf(const []), 0);
    });

    test('константный сигнал даёт RMS, равный себе', () {
      expect(rmsOf(List<double>.filled(64, 0.25)), closeTo(0.25, 1e-9));
    });

    test('знакопеременный сигнал не гасится до нуля', () {
      final samples = List<double>.generate(
        100,
        (i) => i.isEven ? 0.5 : -0.5,
      );

      expect(rmsOf(samples), closeTo(0.5, 1e-9));
    });
  });
}
