import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:voice_message/src/controllers/audio_recording_bloc.dart';
import 'package:voice_message/src/models/spectrum_config.dart';
import 'package:voice_message/src/painters/logarithmic_spectrum_painter.dart';
import 'package:voice_message/src/painters/spectrum_painter.dart';
import 'package:voice_message/src/services/spectrum_analyzer.dart';

/// Real-time spectrogram that updates every audio chunk during recording.
/// Bars reflect the actual sound level — no auto-normalization,
/// silence → flat, speech → tall.
class LiveSpectrumDisplay extends StatelessWidget {
  const LiveSpectrumDisplay({
    super.key,
    this.height = 120.0,
    this.barColor,
    this.barSpacing = 1.0,
    this.spectrumConfig = const SpectrumConfig(),
    this.logarithmic = true,
  });

  final double height;
  final Color? barColor;
  final double barSpacing;
  final SpectrumConfig spectrumConfig;

  /// true — coloured log-scale bands (messenger style);
  /// false — linear with single colour.
  final bool logarithmic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<AudioRecordingBloc, AudioRecordingState>(
      buildWhen: (prev, curr) {
        if (curr is AudioRecordingState$Recording &&
            prev is AudioRecordingState$Recording) {
          return prev.liveSpectrumData != curr.liveSpectrumData;
        }
        return prev.runtimeType != curr.runtimeType;
      },
      builder: (context, state) {
        if (state is! AudioRecordingState$Recording) {
          return SizedBox(height: height);
        }

        final linear = state.liveSpectrumData;
        if (linear.isEmpty) return SizedBox(height: height);

        final spectrum = logarithmic
            ? SpectrumAnalyzer().toLogScale(linear, spectrumConfig)
            : linear;

        final color = barColor ?? theme.colorScheme.primary;
        final minDb = -spectrumConfig.dynamicRangeDb;

        return SizedBox(
          height: height,
          width: double.infinity,
          child: logarithmic
              ? CustomPaint(
                  painter: LogarithmicSpectrumPainter(
                    spectrum: spectrum,
                    baseColor: color,
                    minDb: minDb,
                    frequencyMin: spectrumConfig.frequencyMin,
                    frequencyMax: spectrumConfig.frequencyMax,
                    bands: spectrumConfig.frequencyBands,
                    barSpacing: barSpacing,
                  ),
                )
              : CustomPaint(
                  painter: SpectrumPainter(
                    spectrum: spectrum,
                    barColor: color,
                    minDb: minDb,
                    barSpacing: barSpacing,
                  ),
                ),
        );
      },
    );
  }
}
