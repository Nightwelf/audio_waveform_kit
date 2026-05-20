import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:voice_message/src/controllers/audio_recording_bloc.dart';
import 'package:voice_message/src/models/spectrum_config.dart';
import 'package:voice_message/src/painters/logarithmic_spectrum_painter.dart';
import 'package:voice_message/src/painters/spectrum_painter.dart';
import 'package:voice_message/src/services/spectrum_analyzer.dart';

class SpectrumDisplay extends StatelessWidget {
  const SpectrumDisplay({
    super.key,
    this.height = 120.0,
    this.barColor,
    this.barSpacing = 1.0,
    this.spectrumConfig = const SpectrumConfig(),
    this.logarithmic = false,
  });

  final double height;
  final Color? barColor;
  final double barSpacing;
  final SpectrumConfig spectrumConfig;
  final bool logarithmic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<AudioRecordingBloc, AudioRecordingState>(
      buildWhen: (prev, curr) {
        if (curr is AudioRecordingState$Recording) return true;
        return curr is AudioRecordingState$Finished &&
            prev is! AudioRecordingState$Finished;
      },
      builder: (context, state) {
        if (state is! AudioRecordingState$Finished) {
          return SizedBox(height: height);
        }

        final linear = state.spectrumData;
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
