import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audio_waveform_kit/src/constants.dart';
import 'package:audio_waveform_kit/src/models/recording_result.dart';
import 'package:audio_waveform_kit/src/models/spectrum_config.dart';
import 'package:audio_waveform_kit/src/services/audio_recording_service.dart';
import 'package:audio_waveform_kit/src/services/spectrum_analyzer.dart';
import 'package:audio_waveform_kit/src/utils/audio_utils.dart';
import 'package:audio_waveform_kit/src/utils/rms_bucket_accumulator.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'audio_recording_event.dart';
part 'audio_recording_state.dart';

class AudioRecordingBloc
    extends Bloc<AudioRecordingEvent, AudioRecordingState> {
  AudioRecordingBloc({
    required AudioRecordingService recordingService,
    required SpectrumAnalyzer spectrumAnalyzer,
    this.spectrumConfig = const SpectrumConfig(),
    int maxWaveformSamples = 56,
    int maxSnapshotSamples = 2048,
  })  : _recordingService = recordingService,
        _spectrumAnalyzer = spectrumAnalyzer,
        _maxWaveformSamples = maxWaveformSamples,
        _maxSnapshotSamples = maxSnapshotSamples,
        _rms = RmsBucketAccumulator(maxWaveformSamples),
        super(const AudioRecordingState$Idle()) {
    on<AudioRecordingEvent$Start>(_onStart, transformer: droppable());
    on<AudioRecordingEvent$Stop>(_onStop, transformer: droppable());
    on<AudioRecordingEvent$Reset>(_onReset);
    on<_AudioRecordingEvent$WaveformUpdated>(
      _onWaveformUpdated,
      transformer: sequential(),
    );
    on<_AudioRecordingEvent$TimerTicked>(
      _onTimerTicked,
      transformer: sequential(),
    );
  }

  static const _tag = '[AudioRecordingBloc]';

  /// Минимальный интервал между пересчётами live-спектра, мс.
  static const _liveSpectrumThrottleMs = 50;

  final AudioRecordingService _recordingService;
  final SpectrumAnalyzer _spectrumAnalyzer;
  final SpectrumConfig spectrumConfig;
  final int _maxWaveformSamples;
  final int _maxSnapshotSamples;
  final RmsBucketAccumulator _rms;

  /// Окно RMS: 10 мс при частоте записи из [spectrumConfig].
  late final int _rmsWindowSize = math.max(1, spectrumConfig.sampleRate ~/ 100);

  StreamSubscription<Uint8List>? _audioStreamSub;
  Timer? _timer;
  DateTime? _startTime;
  final List<double> _waveformSamples = [];
  final List<double> _snapshotSamples = [];
  double _rmsSumSq = 0;
  int _rmsCount = 0;
  DateTime? _lastSpectrumAt;
  List<double> _lastSpectrum = const [];

  Future<void> _onStart(
    AudioRecordingEvent$Start event,
    Emitter<AudioRecordingState> emit,
  ) async {
    try {
      _waveformSamples.clear();
      _snapshotSamples.clear();
      _rms.reset();
      _rmsSumSq = 0;
      _rmsCount = 0;
      _lastSpectrumAt = null;
      _lastSpectrum = const [];
      _startTime = DateTime.now();

      final stream = await _recordingService.startStream();

      emit(
        const AudioRecordingState$Recording(
          duration: Duration.zero,
          waveformSamples: [],
          rmsSamples: [],
          snapshotSamples: [],
          liveSpectrumData: [],
        ),
      );

      _audioStreamSub = stream.listen(
        _processChunk,
        onError: (Object _) => add(const AudioRecordingEvent$Stop()),
        // Сервис закрыл поток сам — например, запись остановили из
        // уведомления foreground service. Без этого bloc остался бы в
        // Recording с тикающим таймером.
        onDone: () {
          if (!isClosed && state is AudioRecordingState$Recording) {
            add(const AudioRecordingEvent$Stop());
          }
        },
      );

      _timer = Timer.periodic(
        const Duration(milliseconds: 50),
        (_) {
          final startTime = _startTime;
          if (startTime == null) return;
          add(
            _AudioRecordingEvent$TimerTicked(
              duration: DateTime.now().difference(startTime),
            ),
          );
        },
      );
    } on Object catch (e) {
      emit(AudioRecordingState$Error(message: '$_tag: $e'));
    }
  }

  void _processChunk(Uint8List chunk) {
    // Чанк с платформенного канала — вью в буфер сообщения, со своими
    // offsetInBytes и длиной. Через `chunk.buffer` читались бы чужие байты
    // (служебный заголовок сообщения, соседние куски), а при нечётном
    // смещении PCM16 разъезжается на байт и любой звук превращается в шум
    // полной громкости. В файл при этом пишется корректный чанк — расходятся
    // только визуализация и спектр.
    final int16View = chunk.offsetInBytes.isEven
        ? Int16List.sublistView(chunk)
        : Int16List.sublistView(Uint8List.fromList(chunk));

    // RMS-энергия по окнам ~10 мс (частота — из spectrumConfig.sampleRate).
    // Остаток окна переносится между чанками через _rmsSumSq/_rmsCount —
    // иначе огибающая зависит от того, как плагин нарезал PCM. Каждое
    // завершённое окно идёт и в _rms (бакеты на всю запись, для мессенджера),
    // и в _waveformSamples (скользящее окно последних значений, живой индикатор).
    for (var i = 0; i < int16View.length; i++) {
      final s = int16View[i] / kInt16Scale;
      _rmsSumSq += s * s;
      _rmsCount++;
      if (_rmsCount >= _rmsWindowSize) {
        final rms = math.sqrt(_rmsSumSq / _rmsCount);
        _rms.add(rms);
        _waveformSamples.add(rms);
        _rmsSumSq = 0;
        _rmsCount = 0;
      }
    }
    if (_waveformSamples.length > _maxWaveformSamples) {
      _waveformSamples.removeRange(
        0,
        _waveformSamples.length - _maxWaveformSamples,
      );
    }

    // Raw consecutive samples for oscilloscope/string display
    for (var i = 0; i < int16View.length; i++) {
      _snapshotSamples.add(int16View[i] / kInt16Scale);
    }
    if (_snapshotSamples.length > _maxSnapshotSamples) {
      _snapshotSamples.removeRange(
        0,
        _snapshotSamples.length - _maxSnapshotSamples,
      );
    }

    // Throttle the live FFT so it runs at most once per throttle interval.
    final now = DateTime.now();
    final last = _lastSpectrumAt;
    if (last == null ||
        now.difference(last).inMilliseconds >= _liveSpectrumThrottleMs) {
      _lastSpectrum = _spectrumAnalyzer.analyzeRaw(
        List.unmodifiable(_snapshotSamples),
        spectrumConfig,
      );
      _lastSpectrumAt = now;
    }

    add(
      _AudioRecordingEvent$WaveformUpdated(
        samples: List.unmodifiable(_waveformSamples),
        rmsSamples: _rms.buckets,
        snapshot: List.unmodifiable(_snapshotSamples),
        liveSpectrum: _lastSpectrum,
      ),
    );
  }

  void _onWaveformUpdated(
    _AudioRecordingEvent$WaveformUpdated event,
    Emitter<AudioRecordingState> emit,
  ) {
    final current = state;
    if (current is! AudioRecordingState$Recording) return;
    emit(
      current.copyWith(
        waveformSamples: event.samples,
        rmsSamples: event.rmsSamples,
        snapshotSamples: event.snapshot,
        liveSpectrumData: event.liveSpectrum,
      ),
    );
  }

  void _onTimerTicked(
    _AudioRecordingEvent$TimerTicked event,
    Emitter<AudioRecordingState> emit,
  ) {
    final current = state;
    if (current is! AudioRecordingState$Recording) return;
    emit(current.copyWith(duration: event.duration));
  }

  Future<void> _onStop(
    AudioRecordingEvent$Stop event,
    Emitter<AudioRecordingState> emit,
  ) async {
    _timer?.cancel();
    _timer = null;
    await _audioStreamSub?.cancel();
    _audioStreamSub = null;

    try {
      final startTime = _startTime;
      final duration = startTime != null
          ? DateTime.now().difference(startTime)
          : Duration.zero;

      final filePath = await _recordingService.stop();

      final pcm = _recordingService.recordedBytes;
      Uint8List? wavBytes;
      if (kIsWeb) {
        wavBytes = AudioUtils.encodeWav(
          pcm,
          sampleRate: spectrumConfig.sampleRate,
        );
      }
      final result = await compute(
        _runSpectrumAnalysis,
        (pcmBytes: pcm, config: spectrumConfig),
      );

      _rms.flushPartial();

      emit(
        AudioRecordingState$Finished(
          filePath: filePath,
          wavBytes: wavBytes,
          duration: duration,
          waveformSamples: List.unmodifiable(_waveformSamples),
          rmsSamples: _rms.buckets,
          snapshotSamples: List.unmodifiable(_snapshotSamples),
          spectrumData: result.spectrumData,
          spectrumTimeline: result.spectrumTimeline,
        ),
      );
    } on Object catch (e) {
      emit(AudioRecordingState$Error(message: '$_tag: $e'));
    }
  }

  void _onReset(
    AudioRecordingEvent$Reset event,
    Emitter<AudioRecordingState> emit,
  ) {
    emit(const AudioRecordingState$Idle());
  }

  @override
  Future<void> close() async {
    // Не закрываем _recordingService здесь: им владеет DI-scope
    // (RepositoryProvider.dispose), повторный dispose тут приведёт
    // к двойному освобождению одного и того же ресурса.
    _timer?.cancel();
    await _audioStreamSub?.cancel();
    return super.close();
  }
}

typedef _SpectrumInput = ({Uint8List pcmBytes, SpectrumConfig config});
typedef _SpectrumOutput = ({
  List<double> spectrumData,
  List<List<double>> spectrumTimeline,
});

_SpectrumOutput _runSpectrumAnalysis(_SpectrumInput input) {
  final analyzer = SpectrumAnalyzer();
  return (
    spectrumData: analyzer.analyze(input.pcmBytes, input.config),
    spectrumTimeline: analyzer.computeTimeline(input.pcmBytes, input.config),
  );
}
