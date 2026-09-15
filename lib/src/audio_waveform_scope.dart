import 'package:audio_waveform_kit/src/controllers/audio_recording_bloc.dart';
import 'package:audio_waveform_kit/src/models/spectrum_config.dart';
import 'package:audio_waveform_kit/src/services/audio_recording_service.dart';
import 'package:audio_waveform_kit/src/services/audio_recording_service_impl.dart';
import 'package:audio_waveform_kit/src/services/spectrum_analyzer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// DI scope for the audio_waveform_kit package.
///
/// Wrap the part of your widget tree that uses recording widgets with this.
class AudioWaveformScope extends StatelessWidget {
  const AudioWaveformScope({
    required this.child,
    super.key,
    this.spectrumConfig = const SpectrumConfig(),
    this.maxWaveformSamples = 56,
    this.maxSnapshotSamples = 2048,
    this.recordingService,
  });

  final Widget child;
  final SpectrumConfig spectrumConfig;
  final int maxWaveformSamples;
  final int maxSnapshotSamples;

  /// Custom recording implementation — e.g. one that streams PCM to disk
  /// instead of accumulating it in memory, or runs in a foreground service.
  ///
  /// When null (the default), the scope creates its own
  /// [AudioRecordingServiceImpl] and disposes it with the scope.
  /// When provided, the service is used as-is and **its lifecycle belongs to
  /// the caller** — the scope will not dispose it.
  final AudioRecordingService? recordingService;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        if (recordingService case final AudioRecordingService service)
          RepositoryProvider<AudioRecordingService>.value(value: service)
        else
          RepositoryProvider<AudioRecordingService>(
            create: (_) => AudioRecordingServiceImpl(
              sampleRate: spectrumConfig.sampleRate,
            ),
            dispose: (service) => service.dispose(),
          ),
        RepositoryProvider<SpectrumAnalyzer>(
          create: (_) => SpectrumAnalyzer(),
        ),
      ],
      child: BlocProvider<AudioRecordingBloc>(
        create: (context) => AudioRecordingBloc(
          recordingService: context.read<AudioRecordingService>(),
          spectrumAnalyzer: context.read<SpectrumAnalyzer>(),
          spectrumConfig: spectrumConfig,
          maxWaveformSamples: maxWaveformSamples,
          maxSnapshotSamples: maxSnapshotSamples,
        ),
        child: child,
      ),
    );
  }
}
