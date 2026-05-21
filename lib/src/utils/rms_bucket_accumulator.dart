/// Накапливает RMS-значения по окнам в бакеты для мессенджерного вейвформа.
///
/// Когда число бакетов превышает [maxBuckets], соседние пары сливаются
/// (длина уменьшается вдвое), а размер окна удваивается — так каждый бакет
/// продолжает представлять одинаковую длительность записи.
class RmsBucketAccumulator {
  RmsBucketAccumulator(this.maxBuckets);

  final int maxBuckets;

  final List<double> _buckets = [];
  int _windowsPerBucket = 1;
  double _currentSum = 0;
  int _currentCount = 0;

  /// Неизменяемая копия накопленных бакетов.
  List<double> get buckets => List.unmodifiable(_buckets);

  /// Добавляет одно RMS-окно.
  void add(double rms) {
    _currentSum += rms;
    _currentCount++;
    if (_currentCount >= _windowsPerBucket) {
      _buckets.add(_currentSum / _currentCount);
      _currentSum = 0;
      _currentCount = 0;
      if (_buckets.length > maxBuckets) {
        _merge();
      }
    }
  }

  /// Дозаписывает незавершённый бакет (вызывать при остановке записи).
  void flushPartial() {
    if (_currentCount > 0) {
      _buckets.add(_currentSum / _currentCount);
      _currentSum = 0;
      _currentCount = 0;
    }
  }

  /// Сбрасывает аккумулятор в исходное состояние.
  void reset() {
    _buckets.clear();
    _windowsPerBucket = 1;
    _currentSum = 0;
    _currentCount = 0;
  }

  void _merge() {
    final half = _buckets.length >> 1;
    for (var i = 0; i < half; i++) {
      _buckets[i] = (_buckets[i * 2] + _buckets[i * 2 + 1]) / 2;
    }
    if (_buckets.length.isOdd) {
      _buckets[half] = _buckets[_buckets.length - 1];
      _buckets.length = half + 1;
    } else {
      _buckets.length = half;
    }
    _windowsPerBucket *= 2;
  }
}
