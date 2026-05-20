part of 'audio_recording_bloc.dart';

sealed class AudioRecordingEvent extends Equatable {
  const AudioRecordingEvent();

  @override
  List<Object?> get props => [];
}

class AudioRecordingEvent$Start extends AudioRecordingEvent {
  const AudioRecordingEvent$Start();
}

class AudioRecordingEvent$Stop extends AudioRecordingEvent {
  const AudioRecordingEvent$Stop();
}

class AudioRecordingEvent$Reset extends AudioRecordingEvent {
  const AudioRecordingEvent$Reset();
}

class _AudioRecordingEvent$WaveformUpdated extends AudioRecordingEvent {
  const _AudioRecordingEvent$WaveformUpdated({
    required this.samples,
    required this.rmsSamples,
    required this.snapshot,
    required this.liveSpectrum,
  });

  final List<double> samples;
  final List<double> rmsSamples;
  final List<double> snapshot;
  final List<double> liveSpectrum;

  @override
  List<Object?> get props => [samples, rmsSamples, snapshot, liveSpectrum];
}

class _AudioRecordingEvent$TimerTicked extends AudioRecordingEvent {
  const _AudioRecordingEvent$TimerTicked({required this.duration});

  final Duration duration;

  @override
  List<Object?> get props => [duration];
}
