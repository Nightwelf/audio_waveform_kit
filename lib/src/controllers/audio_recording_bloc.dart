import 'dart:async';
import 'dart:math' as math;

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:voice_message/src/models/spectrum_config.dart';
import 'package:voice_message/src/services/audio_recording_service.dart';
import 'package:voice_message/src/services/audio_recording_service_impl.dart';
import 'package:voice_message/src/services/spectrum_analyzer.dart';
import 'package:voice_message/src/utils/audio_utils.dart';

part 'audio_recording_event.dart';

part 'audio_recording_state.dart';

class AudioRecordingBloc extends Bloc<AudioRecordingEvent, AudioRecordingState> {
  AudioRecordingBloc({
    required AudioRecordingService recordingService,
    required SpectrumAnalyzer spectrumAnalyzer,
    this.spectrumConfig = const SpectrumConfig(),
    int maxWaveformSamples = 56,
    int maxSnapshotSamples = 256,
  })  : _recordingService = recordingService,
        _spectrumAnalyzer = spectrumAnalyzer,
        _maxWaveformSamples = maxWaveformSamples,
        _maxSnapshotSamples = maxSnapshotSamples,
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

  final AudioRecordingService _recordingService;
  final SpectrumAnalyzer _spectrumAnalyzer;
  final SpectrumConfig spectrumConfig;
  final int _maxWaveformSamples;
  final int _maxSnapshotSamples;

  StreamSubscription<Uint8List>? _audioStreamSub;
  Timer? _timer;
  DateTime? _startTime;
  final List<double> _waveformSamples = [];
  final List<double> _snapshotSamples = [];
  final List<double> _rmsBuckets = [];
  int _rmsWindowsPerBucket = 1;
  double _rmsCurrentBucketSum = 0;
  int _rmsCurrentBucketCount = 0;

  Future<void> _onStart(
    AudioRecordingEvent$Start event,
    Emitter<AudioRecordingState> emit,
  ) async {
    try {
      _waveformSamples.clear();
      _snapshotSamples.clear();
      _rmsBuckets.clear();
      _rmsWindowsPerBucket = 1;
      _rmsCurrentBucketSum = 0.0;
      _rmsCurrentBucketCount = 0;
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
    final int16View = chunk.buffer.asInt16List();

    // Downsampled history for waveform/level displays (signed, for string style)
    for (var i = 0; i < int16View.length; i += 441) {
      _waveformSamples.add(int16View[i] / 32768);
      if (_waveformSamples.length > _maxWaveformSamples) {
        _waveformSamples.removeAt(0);
      }
    }

    // RMS energy per 10 ms window (~441 samples at 44100 Hz)
    const rmsWindow = 441;
    final windows = int16View.length ~/ rmsWindow;
    for (var w = 0; w < windows; w++) {
      var sumSq = 0.0;
      final base = w * rmsWindow;
      for (var j = base; j < base + rmsWindow; j++) {
        final s = int16View[j] / 32768;
        sumSq += s * s;
      }
      _addRmsWindow(math.sqrt(sumSq / rmsWindow));
    }

    // Raw consecutive samples for oscilloscope/string display
    for (var i = 0; i < int16View.length; i++) {
      _snapshotSamples.add(int16View[i] / 32768);
      if (_snapshotSamples.length > _maxSnapshotSamples) {
        _snapshotSamples.removeAt(0);
      }
    }

    final liveSpectrum = _spectrumAnalyzer.analyzeRaw(
      List.unmodifiable(_snapshotSamples),
      spectrumConfig,
    );

    add(
      _AudioRecordingEvent$WaveformUpdated(
        samples: List.unmodifiable(_waveformSamples),
        rmsSamples: List.unmodifiable(_rmsBuckets),
        snapshot: List.unmodifiable(_snapshotSamples),
        liveSpectrum: liveSpectrum,
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
      final duration = _startTime != null ? DateTime.now().difference(_startTime!) : Duration.zero;

      final filePath = await _recordingService.stop();

      var spectrumData = <double>[];
      var spectrumTimeline = <List<double>>[];
      Uint8List? wavBytes;
      final service = _recordingService;
      if (service is AudioRecordingServiceImpl) {
        debugPrint('$_tag stop: recordedBytes=${service.recordedBytes.length}');
        final pcm = Uint8List.fromList(service.recordedBytes);
        if (kIsWeb) {
          wavBytes = AudioUtils.encodeWav(service.recordedBytes, sampleRate: 44100);
        }
        final result = await compute(
          _runSpectrumAnalysis,
          (pcmBytes: pcm, config: spectrumConfig),
        );
        spectrumData = result.spectrumData;
        spectrumTimeline = result.spectrumTimeline;
        debugPrint('$_tag spectrumData.length=${spectrumData.length} '
            'timeline frames=${spectrumTimeline.length}');
      }

      if (_rmsCurrentBucketCount > 0) {
        _rmsBuckets.add(_rmsCurrentBucketSum / _rmsCurrentBucketCount);
        _rmsCurrentBucketSum = 0.0;
        _rmsCurrentBucketCount = 0;
      }

      emit(
        AudioRecordingState$Finished(
          filePath: filePath,
          wavBytes: wavBytes,
          duration: duration,
          waveformSamples: List.unmodifiable(_waveformSamples),
          rmsSamples: List.unmodifiable(_rmsBuckets),
          snapshotSamples: List.unmodifiable(_snapshotSamples),
          spectrumData: spectrumData,
          spectrumTimeline: spectrumTimeline,
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

  void _addRmsWindow(double rmsValue) {
    _rmsCurrentBucketSum += rmsValue;
    _rmsCurrentBucketCount++;
    if (_rmsCurrentBucketCount >= _rmsWindowsPerBucket) {
      _rmsBuckets.add(_rmsCurrentBucketSum / _rmsCurrentBucketCount);
      _rmsCurrentBucketSum = 0.0;
      _rmsCurrentBucketCount = 0;
      if (_rmsBuckets.length > _maxWaveformSamples) {
        _mergeBuckets();
      }
    }
  }

  // Merges adjacent bucket pairs to halve the list length, then doubles the
  // window size so future buckets represent the same duration each.
  void _mergeBuckets() {
    final half = _rmsBuckets.length >> 1;
    for (var i = 0; i < half; i++) {
      _rmsBuckets[i] = (_rmsBuckets[i * 2] + _rmsBuckets[i * 2 + 1]) / 2;
    }
    if (_rmsBuckets.length.isOdd) {
      _rmsBuckets[half] = _rmsBuckets[_rmsBuckets.length - 1];
      _rmsBuckets.length = half + 1;
    } else {
      _rmsBuckets.length = half;
    }
    _rmsWindowsPerBucket *= 2;
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    await _audioStreamSub?.cancel();
    await _recordingService.dispose();
    return super.close();
  }
}

typedef _SpectrumInput = ({Uint8List pcmBytes, SpectrumConfig config});
typedef _SpectrumOutput = ({List<double> spectrumData, List<List<double>> spectrumTimeline});

_SpectrumOutput _runSpectrumAnalysis(_SpectrumInput input) {
  final analyzer = SpectrumAnalyzer();
  return (
    spectrumData: analyzer.analyze(input.pcmBytes, input.config),
    spectrumTimeline: analyzer.computeTimeline(input.pcmBytes, input.config),
  );
}
