part of 'audio_player_bloc.dart';

sealed class AudioPlayerState extends Equatable {
  const AudioPlayerState();

  @override
  List<Object?> get props => [];
}

class AudioPlayerState$Idle extends AudioPlayerState {
  const AudioPlayerState$Idle();
}

class AudioPlayerState$Playing extends AudioPlayerState {
  const AudioPlayerState$Playing({
    required this.position,
    required this.duration,
  });

  final Duration position;
  final Duration duration;

  AudioPlayerState$Playing copyWith({
    Duration? position,
    Duration? duration,
  }) =>
      AudioPlayerState$Playing(
        position: position ?? this.position,
        duration: duration ?? this.duration,
      );

  double get progress =>
      duration.inMilliseconds > 0
          ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
          : 0.0;

  @override
  List<Object?> get props => [position, duration];
}

class AudioPlayerState$Paused extends AudioPlayerState {
  const AudioPlayerState$Paused({
    required this.position,
    required this.duration,
  });

  final Duration position;
  final Duration duration;

  double get progress =>
      duration.inMilliseconds > 0
          ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
          : 0.0;

  @override
  List<Object?> get props => [position, duration];
}

class AudioPlayerState$Completed extends AudioPlayerState {
  const AudioPlayerState$Completed({required this.duration});

  final Duration duration;

  @override
  List<Object?> get props => [duration];
}

class AudioPlayerState$Error extends AudioPlayerState {
  const AudioPlayerState$Error({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
