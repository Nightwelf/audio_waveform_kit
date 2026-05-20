import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:voice_message/src/controllers/audio_recording_bloc.dart';
import 'package:voice_message/src/models/spectrum_config.dart';
import 'package:voice_message/src/services/audio_recording_service.dart';
import 'package:voice_message/src/services/audio_recording_service_impl.dart';
import 'package:voice_message/src/services/spectrum_analyzer.dart';

/// DI scope for the voice_message package.
///
/// Wrap the part of your widget tree that uses recording widgets with this.
class VoiceMessageScope extends StatelessWidget {
  const VoiceMessageScope({
    required this.child,
    super.key,
    this.spectrumConfig = const SpectrumConfig(),
    this.maxWaveformSamples = 56,
    this.maxSnapshotSamples = 2048,
  });

  final Widget child;
  final SpectrumConfig spectrumConfig;
  final int maxWaveformSamples;
  final int maxSnapshotSamples;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AudioRecordingService>(
          create: (_) => AudioRecordingServiceImpl(),
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
