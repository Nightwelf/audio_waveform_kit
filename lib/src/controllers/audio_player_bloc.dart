import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'audio_player_event.dart';

part 'audio_player_state.dart';

class AudioPlayerBloc extends Bloc<AudioPlayerEvent, AudioPlayerState> {
  AudioPlayerBloc({required this.filePath, this.audioBytes})
      : _player = AudioPlayer(),
        super(const AudioPlayerState$Idle()) {
    on<AudioPlayerEvent$Play>(_onPlay, transformer: droppable());
    on<AudioPlayerEvent$Pause>(_onPause, transformer: droppable());
    on<AudioPlayerEvent$Stop>(_onStop, transformer: droppable());
    on<AudioPlayerEvent$Seek>(_onSeek);
    on<_AudioPlayerEvent$PositionChanged>(
      _onPositionChanged,
      transformer: sequential(),
    );
    on<_AudioPlayerEvent$DurationChanged>(
      _onDurationChanged,
      transformer: sequential(),
    );
    on<_AudioPlayerEvent$Completed>(_onCompleted, transformer: droppable());

    _positionSub = _player.onPositionChanged.listen(
      (position) => add(_AudioPlayerEvent$PositionChanged(position: position)),
    );
    _durationSub = _player.onDurationChanged.listen(
      (duration) => add(_AudioPlayerEvent$DurationChanged(duration: duration)),
    );
    _completeSub = _player.onPlayerComplete.listen(
      (_) => add(const _AudioPlayerEvent$Completed()),
    );
  }

  final String filePath;

  /// WAV-байты для воспроизведения на web (нет доступа к файловой системе).
  final Uint8List? audioBytes;

  final AudioPlayer _player;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<void>? _completeSub;

  Duration _duration = Duration.zero;

  Future<void> _onPlay(
    AudioPlayerEvent$Play event,
    Emitter<AudioPlayerState> emit,
  ) async {
    try {
      final current = state;
      if (current is AudioPlayerState$Paused) {
        await _player.resume();
        emit(
          AudioPlayerState$Playing(
            position: current.position,
            duration: current.duration,
          ),
        );
      } else {
        final bytes = audioBytes;
        final source = bytes != null
            ? BytesSource(bytes, mimeType: 'audio/wav')
            : DeviceFileSource(filePath);
        await _player.play(source);
        emit(
          AudioPlayerState$Playing(
            position: Duration.zero,
            duration: _duration,
          ),
        );
      }
    } on Object catch (e) {
      emit(AudioPlayerState$Error(message: e.toString()));
    }
  }

  Future<void> _onPause(
    AudioPlayerEvent$Pause event,
    Emitter<AudioPlayerState> emit,
  ) async {
    await _player.pause();
    final current = state;
    if (current is AudioPlayerState$Playing) {
      emit(
        AudioPlayerState$Paused(
          position: current.position,
          duration: current.duration,
        ),
      );
    }
  }

  Future<void> _onStop(
    AudioPlayerEvent$Stop event,
    Emitter<AudioPlayerState> emit,
  ) async {
    await _player.stop();
    emit(const AudioPlayerState$Idle());
  }

  Future<void> _onSeek(
    AudioPlayerEvent$Seek event,
    Emitter<AudioPlayerState> emit,
  ) async {
    await _player.seek(event.position);
  }

  void _onPositionChanged(
    _AudioPlayerEvent$PositionChanged event,
    Emitter<AudioPlayerState> emit,
  ) {
    final current = state;
    if (current is AudioPlayerState$Playing) {
      emit(current.copyWith(position: event.position));
    }
  }

  void _onDurationChanged(
    _AudioPlayerEvent$DurationChanged event,
    Emitter<AudioPlayerState> emit,
  ) {
    _duration = event.duration;
    final current = state;
    if (current is AudioPlayerState$Playing) {
      emit(current.copyWith(duration: event.duration));
    }
  }

  void _onCompleted(
    _AudioPlayerEvent$Completed event,
    Emitter<AudioPlayerState> emit,
  ) {
    emit(AudioPlayerState$Completed(duration: _duration));
  }

  @override
  Future<void> close() async {
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _completeSub?.cancel();
    await _player.dispose();
    return super.close();
  }
}
