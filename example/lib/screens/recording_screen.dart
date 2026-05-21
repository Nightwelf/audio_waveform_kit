import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audio_waveform_kit/audio_waveform_kit.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  RecordingResult? _lastResult;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AudioRecordingBloc, AudioRecordingState>(
      listenWhen: (prev, curr) =>
          curr is AudioRecordingState$Error &&
          prev is! AudioRecordingState$Error,
      listener: (context, state) {
        if (state is AudioRecordingState$Error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 16),
          const RecordingTimer(
            style: TextStyle(
              fontFamily: 'Courier',
              fontFeatures: [FontFeature.tabularFigures()],
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Envelope (timeline, normalized)'),
          const SizedBox(height: 8),
          const WaveformDisplay(height: 80),
          const SizedBox(height: 16),
          const _SectionLabel('String (timeline, normalized)'),
          const SizedBox(height: 8),
          const WaveformDisplay(height: 80, style: WaveformStyle.string),
          const SizedBox(height: 16),
          const _SectionLabel('Snapshot (current moment — oscilloscope)'),
          const SizedBox(height: 8),
          const StringSnapshotDisplay(height: 80),
          const SizedBox(height: 16),
          const _SectionLabel(
              'Messenger waveform — scrolling, normalized (window=100)'),
          const SizedBox(height: 8),
          const MessengerWaveformDisplay(height: 48, windowSize: 100),
          const SizedBox(height: 16),
          const _SectionLabel(
              'Messenger waveform — scrolling, log dB (window=100)'),
          const SizedBox(height: 8),
          const MessengerWaveformDisplay(
              height: 48, logarithmic: true, windowSize: 100),
          const SizedBox(height: 16),
          const _SectionLabel('Level (timeline, raw amplitude)'),
          const SizedBox(height: 8),
          const RecordingLevelDisplay(height: 64),
          const SizedBox(height: 16),
          const _SectionLabel('Live spectrum (messenger style)'),
          const SizedBox(height: 8),
          const LiveSpectrumDisplay(height: 120),
          const SizedBox(height: 32),
          Center(
            child: AudioRecordButton.defaultStyle(
              onRecordingFinished: (result) {
                setState(() => _lastResult = result);
              },
            ),
          ),
          const SizedBox(height: 8),
          const Center(child: _ResetButton()),
          const SizedBox(height: 16),
          if (_lastResult != null) ...[
            _CallbackResultCard(result: _lastResult!),
            const SizedBox(height: 16),
          ],
          _SpectrumSection(),
        ],
      ),
    );
  }
}

class _CallbackResultCard extends StatelessWidget {
  const _CallbackResultCard({required this.result});

  final RecordingResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileInfo =
        kIsWeb ? 'web: ${result.wavBytes!.length} bytes' : result.filePath;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'onRecordingFinished callback result',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _Row('duration', AudioUtils.formatDuration(result.duration)),
            _Row('file', fileInfo),
            _Row('spectrum bins', '${result.spectrumData.length}'),
            _Row('timeline frames', '${result.spectrumTimeline.length}'),
            _Row('rms samples', '${result.rmsSamples.length}'),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 140,
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.labelLarge,
      );
}

class _SpectrumSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioRecordingBloc, AudioRecordingState>(
      buildWhen: (prev, curr) {
        if (curr is AudioRecordingState$Recording) return true;
        return curr is AudioRecordingState$Finished &&
            prev is! AudioRecordingState$Finished;
      },
      builder: (context, state) {
        if (state is! AudioRecordingState$Finished) return const SizedBox();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel('Messenger waveform (normalized peak)'),
            const SizedBox(height: 8),
            StaticMessengerWaveformDisplay(samples: state.rmsSamples),
            const SizedBox(height: 8),
            const _SectionLabel('Messenger waveform (logarithmic dB)'),
            const SizedBox(height: 8),
            StaticMessengerWaveformDisplay(
              samples: state.rmsSamples,
              logarithmic: true,
            ),
            const SizedBox(height: 8),
            const _SectionLabel('Timeline spectrogram'),
            const SizedBox(height: 8),
            const TimelineSpectrumDisplay(height: 140),
            const SizedBox(height: 8),
            const _SectionLabel('Spectrum linear'),
            const SizedBox(height: 8),
            const SpectrumDisplay(height: 100),
            const SizedBox(height: 8),
            const _SectionLabel('Spectrum logarithmic'),
            const SizedBox(height: 8),
            const SpectrumDisplay(height: 100, logarithmic: true),
          ],
        );
      },
    );
  }
}

class _ResetButton extends StatelessWidget {
  const _ResetButton();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioRecordingBloc, AudioRecordingState>(
      buildWhen: (prev, curr) => prev.runtimeType != curr.runtimeType,
      builder: (context, state) {
        if (state is AudioRecordingState$Idle) return const SizedBox.shrink();
        return TextButton.icon(
          onPressed: () => context
              .read<AudioRecordingBloc>()
              .add(const AudioRecordingEvent$Reset()),
          icon: const Icon(Icons.refresh),
          label: const Text('Reset'),
        );
      },
    );
  }
}
