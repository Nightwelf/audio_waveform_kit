import 'dart:math' as math;

import 'package:audio_waveform_kit/src/utils/level_scale.dart';
import 'package:flutter/material.dart';

/// Draws a snapshot of raw PCM samples as a smooth oscilloscope curve —
/// like a vibrating string frozen at one moment in time.
class StringSnapshotPainter extends CustomPainter {
  StringSnapshotPainter({
    required this.samples,
    required this.stringColor,
    this.strokeWidth = 1.5,
    this.minAmplitudeFraction = 0.02,
    this.floorDb = -55.0,
    this.ceilingDb = -15.0,
    this.autoGain = false,
    this.maxGain = 12.0,
    this.pointSpacing = 3.0,
    this.alignToZeroCrossing = true,
  });

  final List<double> samples;
  final Color stringColor;
  final double strokeWidth;

  /// If peak amplitude is below this fraction of max, show a resting string
  /// instead of amplifying noise.
  final double minAmplitudeFraction;

  /// Signal level (dBFS RMS) at which the string lies flat. Everything
  /// quieter is silence.
  final double floorDb;

  /// Signal level (dBFS RMS) at which the string swings across the whole box.
  /// Speech rarely reaches 0 dBFS, so the default leaves headroom below it.
  final double ceilingDb;

  /// Legacy behaviour: normalize every frame to its own peak. Makes quiet
  /// noise fill the whole box and the string jump between frames.
  final bool autoGain;

  /// Upper bound for [autoGain] amplification.
  final double maxGain;

  /// Logical pixels per drawn point; samples in between are averaged.
  /// `0` draws every sample (a dense noise band for raw PCM input).
  final double pointSpacing;

  /// Start the curve at a rising zero crossing, so the wave does not slide
  /// horizontally between frames.
  final bool alignToZeroCrossing;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;

    // Меньше 2 точек — путь через квадратичные кривые не строится
    // (stepX делится на count - 1), рисуем состояние покоя.
    if (samples.length < 2) {
      _drawRestingString(canvas, size, centerY);
      return;
    }

    final peak = samples.fold<double>(0, (m, s) => math.max(m, s.abs()));

    if (peak <= 0 || peak < minAmplitudeFraction) {
      _drawRestingString(canvas, size, centerY);
      return;
    }

    // Размах струны — от уровня сигнала, форма — отдельно: иначе линейное
    // усиление либо режет речь по границе бокса, либо не показывает шум.
    final amplitude = autoGain
        ? math.min(1, peak * maxGain)
        : amplitudeForRms(
            rmsOf(samples),
            floorDb: floorDb,
            ceilingDb: ceilingDb,
          );

    if (amplitude <= 0) {
      _drawRestingString(canvas, size, centerY);
      return;
    }

    final points = prepareStringPoints(
      samples,
      targetPoints: pointSpacing > 0
          ? (size.width / pointSpacing).round() + 1
          : samples.length,
      alignToZeroCrossing: alignToZeroCrossing,
    );

    if (points.length < 2) {
      _drawRestingString(canvas, size, centerY);
      return;
    }

    final path = _buildSmoothedPath(size, centerY, amplitude / peak, points);

    canvas
      ..drawPath(
        path,
        Paint()
          ..color = stringColor.withValues(alpha: 0.25)
          ..strokeWidth = strokeWidth * 5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
          ..isAntiAlias = true,
      )
      ..drawPath(
        path,
        Paint()
          ..color = stringColor
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true,
      );
  }

  Path _buildSmoothedPath(
    Size size,
    double centerY,
    double scale,
    List<double> points,
  ) {
    final count = points.length;
    final stepX = size.width / (count - 1);
    // Линия не срезается по границе бокса (свечение всё равно чуть выходит).
    final half = math.max(1, centerY - strokeWidth);
    double yOf(int i) => centerY - (points[i] * scale).clamp(-1.0, 1.0) * half;

    final path = Path()..moveTo(0, yOf(0));

    // Quadratic bezier through midpoints — gives smooth "string" curve
    for (var i = 1; i < count - 1; i++) {
      final cx = i * stepX;
      final cy = yOf(i);
      final nx = (i + 1) * stepX;
      final ny = yOf(i + 1);
      path.quadraticBezierTo(cx, cy, (cx + nx) / 2, (cy + ny) / 2);
    }

    return path..lineTo((count - 1) * stepX, yOf(count - 1));
  }

  void _drawRestingString(Canvas canvas, Size size, double centerY) {
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      Paint()
        ..color = stringColor.withValues(alpha: 0.4)
        ..strokeWidth = strokeWidth
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(StringSnapshotPainter oldDelegate) =>
      oldDelegate.samples != samples ||
      oldDelegate.stringColor != stringColor ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.minAmplitudeFraction != minAmplitudeFraction ||
      oldDelegate.floorDb != floorDb ||
      oldDelegate.ceilingDb != ceilingDb ||
      oldDelegate.autoGain != autoGain ||
      oldDelegate.maxGain != maxGain ||
      oldDelegate.pointSpacing != pointSpacing ||
      oldDelegate.alignToZeroCrossing != alignToZeroCrossing;
}

/// Сводит [samples] ровно к [targetPoints] точкам усреднением — это
/// низкочастотный фильтр, без него сырые 44.1 кГц превращаются на экране в
/// полосу шума, а не в струну. При [alignToZeroCrossing] начало сдвигается к
/// первому переходу через ноль снизу вверх, чтобы волна не ползла по
/// горизонтали от кадра к кадру.
///
/// Сдвиг берётся из запаса лишних точек, а не из хвоста: количество точек на
/// выходе постоянно, иначе горизонтальный масштаб дышал бы на каждом кадре.
/// Меньше [targetPoints] возвращается только если столько и было сэмплов.
@visibleForTesting
List<double> prepareStringPoints(
  List<double> samples, {
  required int targetPoints,
  bool alignToZeroCrossing = true,
}) {
  if (samples.length < 2) return samples;

  final target = targetPoints.clamp(2, samples.length);
  final headroom = alignToZeroCrossing ? target ~/ 3 : 0;
  final count = math.min(target + headroom, samples.length);
  final points = count >= samples.length
      ? samples
      : List<double>.generate(count, (i) {
          final start = i * samples.length ~/ count;
          final end = math.max(start + 1, (i + 1) * samples.length ~/ count);
          var sum = 0.0;
          for (var j = start; j < end; j++) {
            sum += samples[j];
          }
          return sum / (end - start);
        });

  // Триггер ищем только в пределах запаса — тогда после сдвига точек всегда
  // хватает на полное окно.
  var from = 0;
  final limit = points.length - target;
  for (var i = 1; i <= limit; i++) {
    if (points[i - 1] <= 0 && points[i] > 0) {
      from = i - 1;
      break;
    }
  }

  return points.sublist(from, from + target);
}
