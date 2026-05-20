part of 'audio_player_bloc.dart';

sealed class AudioPlayerEvent extends Equatable {
  const AudioPlayerEvent();

  @override
  List<Object?> get props => [];
}

class AudioPlayerEvent$Play extends AudioPlayerEvent {
  const AudioPlayerEvent$Play();
}

class AudioPlayerEvent$Pause extends AudioPlayerEvent {
  const AudioPlayerEvent$Pause();
}

class AudioPlayerEvent$Stop extends AudioPlayerEvent {
  const AudioPlayerEvent$Stop();
}

class AudioPlayerEvent$Seek extends AudioPlayerEvent {
  const AudioPlayerEvent$Seek({required this.position});

  final Duration position;

  @override
  List<Object?> get props => [position];
}

class _AudioPlayerEvent$PositionChanged extends AudioPlayerEvent {
  const _AudioPlayerEvent$PositionChanged({required this.position});

  final Duration position;

  @override
  List<Object?> get props => [position];
}

class _AudioPlayerEvent$DurationChanged extends AudioPlayerEvent {
  const _AudioPlayerEvent$DurationChanged({required this.duration});

  final Duration duration;

  @override
  List<Object?> get props => [duration];
}

class _AudioPlayerEvent$Completed extends AudioPlayerEvent {
  const _AudioPlayerEvent$Completed();
}
