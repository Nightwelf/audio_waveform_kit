enum SpectrumDisplayType { linear, logarithmic }

class SpectrumConfig {
  const SpectrumConfig({
    this.fftSize = 1024,
    this.displayType = SpectrumDisplayType.linear,
    this.frequencyMin = 20,
    this.frequencyMax = 20000,
    this.frequencyBands = 64,
    this.sampleRate = 44100,
    this.dynamicRangeDb = 60.0,
  })  : assert(
          fftSize > 0 && (fftSize & (fftSize - 1)) == 0,
          'fftSize must be a power of two',
        ),
        assert(
          frequencyMin > 0 && frequencyMin < frequencyMax,
          'frequencyMin must be > 0 and < frequencyMax',
        ),
        assert(frequencyBands > 0, 'frequencyBands must be > 0'),
        assert(sampleRate > 0, 'sampleRate must be > 0');

  final int fftSize;
  final SpectrumDisplayType displayType;
  final double frequencyMin;
  final double frequencyMax;
  final int frequencyBands;
  final int sampleRate;

  /// How many dB below the loudest bin are shown.
  /// Lower = fewer bars but more prominent; higher = more bars including quiet ones.
  final double dynamicRangeDb;
}
