import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:voice_message/voice_message.dart';

class PlaybackScreen extends StatelessWidget {
  const PlaybackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioRecordingBloc, AudioRecordingState>(
      buildWhen: (prev, curr) => prev.runtimeType != curr.runtimeType,
      builder: (context, state) {
        if (state is! AudioRecordingState$Finished) {
          return const Center(
            child: Text('Record a voice message first.'),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Recording', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              state.filePath,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: VoiceMessagePlayer(filePath: state.filePath),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Envelope (timeline, normalized)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            const WaveformDisplay(),
            const SizedBox(height: 16),
            Text(
              'String (timeline, normalized)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            const WaveformDisplay(style: WaveformStyle.string),
            const SizedBox(height: 16),
            Text(
              'Snapshot (last moment — oscilloscope)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            const StringSnapshotDisplay(),
            const SizedBox(height: 16),
            Text(
              'Level (timeline, raw amplitude)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            const RecordingLevelDisplay(),
            const SizedBox(height: 24),
            Text(
              'Timeline spectrum (time × energy + centroid colour)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            const TimelineSpectrumDisplay(),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}
