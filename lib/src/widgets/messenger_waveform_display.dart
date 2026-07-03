import 'package:audio_waveform_kit/src/controllers/audio_recording_bloc.dart';
import 'package:audio_waveform_kit/src/painters/messenger_waveform_painter.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const _listEquality = ListEquality<double>();

/// Messenger-style waveform timeline (WhatsApp / Telegram look).
///
/// Uses RMS energy per 10 ms window. Two display modes:
///
/// **Scrolling (live recording)** — set [windowSize] to the number of bars
/// to show. Only the latest [windowSize] samples are rendered, so new bars
/// appear on the right while old ones slide off the left.
///
/// **Full timeline (static / finished)** — leave [windowSize] null.
/// All accumulated samples are shown, scaled to fit the widget width.
///
/// Two amplitude scaling modes via [logarithmic]:
/// - false (default): global peak normalisation (WhatsApp / Telegram look).
/// - true: dB scaling — quiet speech stays visible.
class MessengerWaveformDisplay extends StatelessWidget {
  const MessengerWaveformDisplay({
    super.key,
    this.height = 48.0,
    this.barColor,
    this.barSpacing = 2.0,
    this.silenceThreshold = 0.02,
    this.logarithmic = false,
    this.minDbThreshold = -60.0,
    this.windowSize,
  });

  final double height;
  final Color? barColor;
  final double barSpacing;
  final double silenceThreshold;

  /// true → dB scaling; false → global peak normalisation.
  final bool logarithmic;
  final double minDbThreshold;

  /// If set, only the latest [windowSize] RMS samples are shown (scrolling).
  /// If null, all accumulated samples are shown (full timeline).
  final int? windowSize;

  @override
  Widget build(BuildContext context) {
    final color = barColor ?? Theme.of(context).colorScheme.primary;

    return BlocBuilder<AudioRecordingBloc, AudioRecordingState>(
      buildWhen: _buildWhen,
      builder: (context, state) {
        final allSamples = switch (state) {
          AudioRecordingState$Recording(:final rmsSamples) => rmsSamples,
          AudioRecordingState$Finished(:final rmsSamples) => rmsSamples,
          _ => const <double>[],
        };

        final w = windowSize;
        final samples = w != null && allSamples.length > w
            ? allSamples.sublist(allSamples.length - w)
            : allSamples;

        return SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: MessengerWaveformPainter(
              samples: samples,
              barColor: color,
              barSpacing: barSpacing,
              silenceThreshold: silenceThreshold,
              logarithmic: logarithmic,
              minDbThreshold: minDbThreshold,
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
      return !_listEquality.equals(prev.rmsSamples, curr.rmsSamples);
    }
    return prev.runtimeType != curr.runtimeType;
  }
}
