import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audio_waveform_kit/src/constants.dart';
import 'package:audio_waveform_kit/src/models/spectrum_config.dart';

class SpectrumAnalyzer {
  /// Computes FFT spectrum from raw PCM16LE bytes.
  ///
  /// Averages magnitude across all overlapping windows, then auto-normalizes
  /// so the loudest bin = 0 dB. Returns dB values for [config.fftSize / 2] bins.
  List<double> analyze(List<int> pcmBytes, SpectrumConfig config) {
    final n = config.fftSize;
    final binCount = n ~/ 2;

    final bytes = pcmBytes.length.isOdd
        ? pcmBytes.sublist(0, pcmBytes.length - 1)
        : pcmBytes;

    if (bytes.length < n * 2) {
      return List.filled(binCount, -80);
    }

    final int16View = Uint8List.fromList(bytes).buffer.asInt16List();

    final hann = _hann(n);

    // Accumulate magnitudes across 50%-overlapping windows
    final sumMag = List<double>.filled(binCount, 0);
    var windowCount = 0;
    final hop = n ~/ 2;

    for (var start = 0; start + n <= int16View.length; start += hop) {
      final real = List<double>.filled(n, 0);
      final imag = List<double>.filled(n, 0);
      for (var i = 0; i < n; i++) {
        real[i] = (int16View[start + i] / kInt16Scale) * hann[i];
      }
      _fft(real, imag);
      for (var k = 0; k < binCount; k++) {
        sumMag[k] +=
            math.sqrt(real[k] * real[k] + imag[k] * imag[k]) / binCount;
      }
      windowCount++;
    }

    if (windowCount == 0) return List.filled(binCount, -80);

    // Average in linear scale
    final avgMag =
        List<double>.generate(binCount, (i) => sumMag[i] / windowCount);

    // Auto-normalize: peak bin → 0 dB, so quiet recordings fill the display
    final peak = avgMag.reduce(math.max);

    return List<double>.generate(binCount, (i) {
      if (peak <= 0) return -80.0;
      final normalized = avgMag[i] / peak;
      if (normalized <= 0) return -80.0;
      return (20 * math.log(normalized) / math.ln10).clamp(-80.0, 0.0);
    });
  }

  /// Divides the recording into up to [maxFrames] time slices and computes
  /// log-scale band magnitudes (linear, not dB) for each.
  ///
  /// Returns a `frames × bands` matrix. Use with TimelineSpectrumPainter.
  List<List<double>> computeTimeline(
    List<int> pcmBytes,
    SpectrumConfig config, {
    int maxFrames = 200,
  }) {
    final n = config.fftSize;

    final bytes = pcmBytes.length.isOdd
        ? pcmBytes.sublist(0, pcmBytes.length - 1)
        : pcmBytes;

    if (bytes.length < n * 2) return [];

    final int16View = Uint8List.fromList(bytes).buffer.asInt16List();
    final hop = math.max(n ~/ 2, int16View.length ~/ maxFrames);

    final hann = _hann(n);

    final timeline = <List<double>>[];

    for (var start = 0; start + n <= int16View.length; start += hop) {
      final real = List<double>.filled(n, 0);
      final imag = List<double>.filled(n, 0);
      for (var i = 0; i < n; i++) {
        real[i] = (int16View[start + i] / kInt16Scale) * hann[i];
      }
      _fft(real, imag);

      final binCount = n ~/ 2;
      final linearMags = List<double>.generate(binCount, (i) {
        return math.sqrt(real[i] * real[i] + imag[i] * imag[i]) / binCount;
      });

      timeline.add(toLogScale(linearMags, config));
    }

    return timeline;
  }

  /// Single FFT window on already-normalised float [samples] — for live display.
  ///
  /// No averaging, no auto-normalisation: bars reflect the real current level.
  /// Returns dB values for [config.fftSize / 2] bins.
  List<double> analyzeRaw(List<double> samples, SpectrumConfig config) {
    final n = config.fftSize;
    final binCount = n ~/ 2;
    if (samples.length < n) return List.filled(binCount, -80);

    final real = List<double>.filled(n, 0);
    final imag = List<double>.filled(n, 0);
    final start = samples.length - n;
    final hann = _hann(n);

    for (var i = 0; i < n; i++) {
      real[i] = samples[start + i] * hann[i];
    }

    _fft(real, imag);

    return List.generate(binCount, (i) {
      final mag = math.sqrt(real[i] * real[i] + imag[i] * imag[i]) / binCount;
      if (mag <= 0) return -80.0;
      return (20 * math.log(mag) / math.ln10).clamp(-80.0, 0.0);
    });
  }

  /// Maps a linear FFT spectrum to log-scale bands.
  List<double> toLogScale(List<double> spectrum, SpectrumConfig config) {
    final bands = config.frequencyBands;
    final nyquist = config.sampleRate / 2.0;
    final fBins = spectrum.length;

    return List.generate(bands, (band) {
      final t = bands > 1 ? band / (bands - 1) : 0.0;
      final logFreq = config.frequencyMin *
          math.pow(config.frequencyMax / config.frequencyMin, t);
      final binIdx = (logFreq / nyquist * fBins).round().clamp(0, fBins - 1);
      return spectrum[binIdx];
    });
  }

  /// Pre-computed Hann window of length [n].
  List<double> _hann(int n) => List<double>.generate(
        n,
        (i) => 0.5 - 0.5 * math.cos(2 * math.pi * i / (n - 1)),
      );

  void _fft(List<double> real, List<double> imag) {
    final n = real.length;

    var j = 0;
    for (var i = 1; i < n; i++) {
      var bit = n >> 1;
      for (; j & bit != 0; bit >>= 1) {
        j ^= bit;
      }
      j ^= bit;
      if (i < j) {
        final tR = real[i];
        real[i] = real[j];
        real[j] = tR;
        final tI = imag[i];
        imag[i] = imag[j];
        imag[j] = tI;
      }
    }

    for (var len = 2; len <= n; len <<= 1) {
      final angle = -2 * math.pi / len;
      final wR = math.cos(angle);
      final wI = math.sin(angle);

      for (var i = 0; i < n; i += len) {
        var curR = 1.0;
        var curI = 0.0;
        final half = len >> 1;
        for (var k = 0; k < half; k++) {
          final uR = real[i + k];
          final uI = imag[i + k];
          final vR = real[i + k + half] * curR - imag[i + k + half] * curI;
          final vI = real[i + k + half] * curI + imag[i + k + half] * curR;

          real[i + k] = uR + vR;
          imag[i + k] = uI + vI;
          real[i + k + half] = uR - vR;
          imag[i + k + half] = uI - vI;

          final newCurR = curR * wR - curI * wI;
          curI = curR * wI + curI * wR;
          curR = newCurR;
        }
      }
    }
  }
}
