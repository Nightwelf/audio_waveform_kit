import 'dart:typed_data';

class RecordingResult {
  const RecordingResult({
    required this.filePath,
    required this.duration,
    required this.waveformSamples,
    required this.rmsSamples,
    required this.snapshotSamples,
    required this.spectrumData,
    required this.spectrumTimeline,
    this.wavBytes,
  });

  /// Путь к WAV-файлу на нативных платформах.
  /// На вебе — сгенерированный ключ вида `vm_<timestamp>`; используй [wavBytes] для воспроизведения.
  final String filePath;

  /// WAV-байты. Не-null только на вебе (нет доступа к файловой системе).
  final Uint8List? wavBytes;

  final Duration duration;

  /// Нормализованные амплитуды (downsampled) для визуализации огибающей.
  final List<double> waveformSamples;

  /// RMS-энергия по 10 мс окнам — для мессенджерного вейвформа.
  final List<double> rmsSamples;

  /// Короткое окно последовательных PCM-сэмплов для осциллографа.
  final List<double> snapshotSamples;

  /// FFT-магнитуды в дБ (–80…0) усреднённые по всей записи — по бинам.
  final List<double> spectrumData;

  /// Временно-частотная матрица [кадры × полосы] — для TimelineSpectrumDisplay.
  final List<List<double>> spectrumTimeline;
}
