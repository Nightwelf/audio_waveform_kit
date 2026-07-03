import 'package:audio_waveform_kit/src/controllers/audio_recording_bloc.dart';
import 'package:audio_waveform_kit/src/models/spectrum_config.dart';
import 'package:audio_waveform_kit/src/painters/logarithmic_spectrum_painter.dart';
import 'package:audio_waveform_kit/src/painters/spectrum_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SpectrumDisplay extends StatelessWidget {
  const SpectrumDisplay({
    super.key,
    this.height = 120.0,
    this.barColor,
    this.barSpacing = 1.0,
    this.logarithmic = false,
  });

  final double height;
  final Color? barColor;
  final double barSpacing;
  final bool logarithmic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = context.select<AudioRecordingBloc, SpectrumConfig>(
      (bloc) => bloc.spectrumConfig,
    );

    return BlocBuilder<AudioRecordingBloc, AudioRecordingState>(
      buildWhen: (prev, curr) => prev.runtimeType != curr.runtimeType,
      builder: (context, state) {
        if (state is! AudioRecordingState$Finished) {
          return SizedBox(height: height);
        }

        final spectrum = state.spectrumData;
        final color = barColor ?? theme.colorScheme.primary;
        final minDb = -config.dynamicRangeDb;

        return SizedBox(
          height: height,
          width: double.infinity,
          child: logarithmic
              ? CustomPaint(
                  painter: LogarithmicSpectrumPainter(
                    spectrum: spectrum,
                    baseColor: color,
                    minDb: minDb,
                    frequencyMin: config.frequencyMin,
                    frequencyMax: config.frequencyMax,
                    sampleRate: config.sampleRate,
                    bands: config.frequencyBands,
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
