import 'package:audio_waveform_kit/src/controllers/audio_recording_bloc.dart';
import 'package:audio_waveform_kit/src/painters/waveform_painter.dart';
import 'package:audio_waveform_kit/src/widgets/string_snapshot_display.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const _listEquality = ListEquality<double>();

class WaveformDisplay extends StatelessWidget {
  const WaveformDisplay({
    super.key,
    this.waveColor,
    this.baselineColor,
    this.strokeWidth = 2.0,
    this.height = 80.0,
    this.style = WaveformStyle.envelope,
    this.floorDb = -55.0,
    this.ceilingDb = -15.0,
  });

  final Color? waveColor;
  final Color? baselineColor;
  final double strokeWidth;
  final double height;
  final WaveformStyle style;

  /// See [WaveformPainter.floorDb]. Ignored for `WaveformStyle.string`.
  final double floorDb;

  /// See [WaveformPainter.ceilingDb]. Ignored for `WaveformStyle.string`.
  final double ceilingDb;

  @override
  Widget build(BuildContext context) {
    // Струна — уже готовый рендерер снапшота, а не дубль на децимированных
    // отсчётах: он читает snapshotSamples и умеет форму и триггер по нулю.
    if (style == WaveformStyle.string) {
      return StringSnapshotDisplay(
        stringColor: waveColor,
        strokeWidth: strokeWidth,
        height: height,
      );
    }

    final theme = Theme.of(context);

    return BlocBuilder<AudioRecordingBloc, AudioRecordingState>(
      buildWhen: _buildWhen,
      builder: (context, state) {
        final samples = switch (state) {
          AudioRecordingState$Recording(:final waveformSamples) =>
            waveformSamples,
          AudioRecordingState$Finished(:final waveformSamples) =>
            waveformSamples,
          _ => const <double>[],
        };

        return SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: WaveformPainter(
              samples: samples,
              waveColor: waveColor ?? theme.colorScheme.primary,
              baselineColor: baselineColor ?? theme.colorScheme.outlineVariant,
              strokeWidth: strokeWidth,
              floorDb: floorDb,
              ceilingDb: ceilingDb,
            ),
          ),
        );
      },
    );
  }

  static bool _buildWhen(
    AudioRecordingState prev,
    AudioRecordingState curr,
  ) {
    if (prev is AudioRecordingState$Recording &&
        curr is AudioRecordingState$Recording) {
      return !_listEquality.equals(prev.waveformSamples, curr.waveformSamples);
    }
    return prev.runtimeType != curr.runtimeType;
  }
}
