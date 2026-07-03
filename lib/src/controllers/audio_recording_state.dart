part of 'audio_recording_bloc.dart';

sealed class AudioRecordingState extends Equatable {
  const AudioRecordingState();

  @override
  List<Object?> get props => [];
}

class AudioRecordingState$Idle extends AudioRecordingState {
  const AudioRecordingState$Idle();
}

class AudioRecordingState$Recording extends AudioRecordingState {
  const AudioRecordingState$Recording({
    required this.duration,
    required this.waveformSamples,
    required this.rmsSamples,
    required this.snapshotSamples,
    required this.liveSpectrumData,
  });

  final Duration duration;
  final List<double> waveformSamples;

  /// RMS energy per 10 ms window — used for messenger-style waveform display.
  final List<double> rmsSamples;

  /// Short window of consecutive raw PCM samples for oscilloscope display.
  final List<double> snapshotSamples;

  /// Live FFT magnitudes in dB — updated every audio chunk.
  final List<double> liveSpectrumData;

  AudioRecordingState$Recording copyWith({
    Duration? duration,
    List<double>? waveformSamples,
    List<double>? rmsSamples,
    List<double>? snapshotSamples,
    List<double>? liveSpectrumData,
  }) =>
      AudioRecordingState$Recording(
        duration: duration ?? this.duration,
        waveformSamples: waveformSamples ?? this.waveformSamples,
        rmsSamples: rmsSamples ?? this.rmsSamples,
        snapshotSamples: snapshotSamples ?? this.snapshotSamples,
        liveSpectrumData: liveSpectrumData ?? this.liveSpectrumData,
      );

  @override
  List<Object?> get props => [
        duration,
        waveformSamples,
        rmsSamples,
        snapshotSamples,
        liveSpectrumData,
      ];
}

class AudioRecordingState$Finished extends AudioRecordingState {
  const AudioRecordingState$Finished({
    required this.filePath,
    required this.duration,
    required this.waveformSamples,
    required this.rmsSamples,
    required this.snapshotSamples,
    required this.spectrumData,
    required this.spectrumTimeline,
    this.wavBytes,
  });

  final String filePath;

  /// WAV audio bytes. Non-null on web (no file system access), null on native.
  final Uint8List? wavBytes;

  final Duration duration;
  final List<double> waveformSamples;

  /// RMS energy per 10 ms window — used for messenger-style waveform display.
  final List<double> rmsSamples;

  final List<double> snapshotSamples;

  /// FFT magnitude in dB (–80…0), one value per frequency bin.
  final List<double> spectrumData;

  /// Time-frequency matrix: [frames × frequencyBands], linear magnitudes.
  /// Used by TimelineSpectrumDisplay.
  final List<List<double>> spectrumTimeline;

  /// Единая точка маппинга state → публичный DTO, чтобы новые поля
  /// добавлялись только здесь, а не дублировались в вызывающем коде.
  RecordingResult toRecordingResult() => RecordingResult(
        filePath: filePath,
        wavBytes: wavBytes,
        duration: duration,
        waveformSamples: waveformSamples,
        rmsSamples: rmsSamples,
        snapshotSamples: snapshotSamples,
        spectrumData: spectrumData,
        spectrumTimeline: spectrumTimeline,
      );

  @override
  List<Object?> get props => [
        filePath,
        wavBytes,
        duration,
        waveformSamples,
        rmsSamples,
        snapshotSamples,
        spectrumData,
        spectrumTimeline,
      ];
}

class AudioRecordingState$Error extends AudioRecordingState {
  const AudioRecordingState$Error({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
