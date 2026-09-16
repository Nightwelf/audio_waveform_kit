import 'dart:math' as math;

/// RMS набора сэмплов.
double rmsOf(List<double> samples) {
  if (samples.isEmpty) return 0;

  var sumSq = 0.0;
  for (final s in samples) {
    sumSq += s * s;
  }
  return math.sqrt(sumSq / samples.length);
}

/// Размах 0…1 по уровню RMS, логарифмически: между шумом комнаты и речью
/// 30–40 дБ, линейной шкалой оба конца не показать — тихое сливается с нулём
/// либо громкое упирается в границу бокса.
double amplitudeForRms(
  double rms, {
  required double floorDb,
  required double ceilingDb,
}) {
  if (rms <= 0) return 0;

  final db = 20 * math.log(rms) / math.ln10;
  final span = math.max(1e-6, ceilingDb - floorDb);
  return ((db - floorDb) / span).clamp(0.0, 1.0);
}
