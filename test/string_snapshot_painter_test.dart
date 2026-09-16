import 'dart:math' as math;

import 'package:audio_waveform_kit/src/painters/string_snapshot_painter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('prepareStringPoints', () {
    test('усредняет сэмплы до targetPoints', () {
      final points = prepareStringPoints(
        List<double>.filled(1000, 0.5),
        targetPoints: 100,
        alignToZeroCrossing: false,
      );

      expect(points, hasLength(100));
      expect(points.every((p) => (p - 0.5).abs() < 1e-9), isTrue);
    });

    test('усреднение гасит частоту выше шага децимации', () {
      // Знакопеременный сигнал: соседние сэмплы компенсируют друг друга.
      final samples = List<double>.generate(
        1024,
        (i) => i.isEven ? 1.0 : -1.0,
      );

      final points = prepareStringPoints(
        samples,
        targetPoints: 128,
        alignToZeroCrossing: false,
      );

      expect(points.every((p) => p.abs() < 0.2), isTrue);
    });

    test('не растягивает список, если сэмплов меньше запрошенного', () {
      final points = prepareStringPoints(
        const [0.1, 0.2, 0.3],
        targetPoints: 100,
        alignToZeroCrossing: false,
      );

      expect(points, hasLength(3));
    });

    test('сдвигает начало к переходу через ноль снизу вверх', () {
      // Синус со сдвигом фазы: без триггера кривая начинается с максимума.
      final samples = List<double>.generate(
        1024,
        (i) => math.sin(2 * math.pi * 4 * i / 1024 + math.pi / 2),
      );

      final aligned = prepareStringPoints(samples, targetPoints: 128);

      expect(aligned.first <= 0, isTrue);
      expect(aligned[1] > 0, isTrue);
      expect(aligned, hasLength(128));
    });

    test('вырожденный вход не падает на clamp', () {
      expect(prepareStringPoints(const [0.5], targetPoints: 128), hasLength(1));
      expect(prepareStringPoints(const [], targetPoints: 128), isEmpty);
    });

    test('длина окна не зависит от того, нашёлся ли триггер', () {
      final silence = prepareStringPoints(
        List<double>.filled(512, 0.3),
        targetPoints: 64,
      );
      final sine = prepareStringPoints(
        List<double>.generate(512, (i) => math.sin(2 * math.pi * 4 * i / 512)),
        targetPoints: 64,
      );

      expect(silence, hasLength(64));
      expect(sine, hasLength(64));
    });
  });
}
