import 'dart:typed_data';

import 'package:audio_waveform_kit/src/controllers/audio_player_bloc.dart';
import 'package:audio_waveform_kit/src/utils/audio_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AudioWaveformPlayer extends StatelessWidget {
  const AudioWaveformPlayer({
    required this.filePath,
    super.key,
    this.audioBytes,
  });

  final String filePath;

  /// WAV-байты для воспроизведения на web. На нативных платформах не нужны.
  final Uint8List? audioBytes;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          AudioPlayerBloc(filePath: filePath, audioBytes: audioBytes),
      child: const _PlayerView(),
    );
  }
}

class _PlayerView extends StatelessWidget {
  const _PlayerView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioPlayerBloc, AudioPlayerState>(
      builder: (context, state) {
        final isPlaying = state is AudioPlayerState$Playing;
        final progress = switch (state) {
          AudioPlayerState$Playing(:final progress) => progress,
          AudioPlayerState$Paused(:final progress) => progress,
          AudioPlayerState$Completed() => 1.0,
          _ => 0.0,
        };
        final position = switch (state) {
          AudioPlayerState$Playing(:final position) => position,
          AudioPlayerState$Paused(:final position) => position,
          _ => Duration.zero,
        };
        final duration = switch (state) {
          AudioPlayerState$Playing(:final duration) => duration,
          AudioPlayerState$Paused(:final duration) => duration,
          AudioPlayerState$Completed(:final duration) => duration,
          _ => Duration.zero,
        };

        return Row(
          children: [
            _PlayPauseButton(
              isPlaying: isPlaying,
              isCompleted: state is AudioPlayerState$Completed,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProgressBar(progress: progress, duration: duration),
                  const SizedBox(height: 2),
                  _TimeLabel(position: position, duration: duration),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.isPlaying,
    required this.isCompleted,
  });

  final bool isPlaying;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: 40,
      icon: Icon(
        isPlaying
            ? Icons.pause_circle_filled
            : (isCompleted
                ? Icons.replay_circle_filled
                : Icons.play_circle_filled),
      ),
      onPressed: () {
        final bloc = context.read<AudioPlayerBloc>();
        if (isPlaying) {
          bloc.add(const AudioPlayerEvent$Pause());
        } else {
          bloc.add(const AudioPlayerEvent$Play());
        }
      },
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.progress,
    required this.duration,
  });

  final double progress;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        final renderObject = context.findRenderObject();
        if (renderObject is! RenderBox) return;
        final relative = details.localPosition.dx / renderObject.size.width;
        final position = Duration(
          milliseconds: (duration.inMilliseconds * relative).round(),
        );
        context
            .read<AudioPlayerBloc>()
            .add(AudioPlayerEvent$Seek(position: position));
      },
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 4,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _TimeLabel extends StatelessWidget {
  const _TimeLabel({
    required this.position,
    required this.duration,
  });

  final Duration position;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${AudioUtils.formatDuration(position)} / ${AudioUtils.formatDuration(duration)}',
      style: Theme.of(context).textTheme.labelSmall,
    );
  }
}
