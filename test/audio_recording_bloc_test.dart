import 'dart:async';
import 'dart:typed_data';

import 'package:audio_waveform_kit/src/controllers/audio_recording_bloc.dart';
import 'package:audio_waveform_kit/src/services/audio_recording_service.dart';
import 'package:audio_waveform_kit/src/services/spectrum_analyzer.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

/// Управляемая подделка сервиса записи: чанки PCM подаются вручную через
/// [controller], `recordedBytes` отдаёт пустой буфер.
class FakeAudioRecordingService implements AudioRecordingService {
  final StreamController<Uint8List> controller =
      StreamController<Uint8List>.broadcast();
  bool disposed = false;

  @override
  Future<Stream<Uint8List>> startStream() async => controller.stream;

  @override
  Future<String> stop() async => '/tmp/fake_vm.wav';

  @override
  Uint8List get recordedBytes => Uint8List(0);

  @override
  Future<void> dispose() async {
    disposed = true;
    if (!controller.isClosed) await controller.close();
  }
}

void main() {
  group('AudioRecordingBloc', () {
    late FakeAudioRecordingService service;

    setUp(() => service = FakeAudioRecordingService());

    AudioRecordingBloc buildBloc() => AudioRecordingBloc(
          recordingService: service,
          spectrumAnalyzer: SpectrumAnalyzer(),
        );

    test('initial state is Idle', () async {
      final bloc = buildBloc();
      expect(bloc.state, isA<AudioRecordingState$Idle>());
      await bloc.close();
    });

    blocTest<AudioRecordingBloc, AudioRecordingState>(
      'enters Recording state on Start',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const AudioRecordingEvent$Start());
        await Future<void>.delayed(const Duration(milliseconds: 30));
      },
      verify: (bloc) {
        expect(bloc.state, isA<AudioRecordingState$Recording>());
      },
    );

    blocTest<AudioRecordingBloc, AudioRecordingState>(
      'processes an audio chunk into non-empty samples',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const AudioRecordingEvent$Start());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        service.controller.add(Uint8List(882 * 2));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
      verify: (bloc) {
        final state = bloc.state;
        expect(state, isA<AudioRecordingState$Recording>());
        expect(
          (state as AudioRecordingState$Recording).waveformSamples,
          isNotEmpty,
        );
      },
    );

    blocTest<AudioRecordingBloc, AudioRecordingState>(
      'emits Finished with the file path on Stop',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const AudioRecordingEvent$Start());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const AudioRecordingEvent$Stop());
      },
      wait: const Duration(milliseconds: 400),
      verify: (bloc) {
        final state = bloc.state;
        expect(state, isA<AudioRecordingState$Finished>());
        expect(
          (state as AudioRecordingState$Finished).filePath,
          '/tmp/fake_vm.wav',
        );
      },
    );

    blocTest<AudioRecordingBloc, AudioRecordingState>(
      'leaves Recording state after a stream error',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const AudioRecordingEvent$Start());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        service.controller.addError(Exception('mic failure'));
      },
      wait: const Duration(milliseconds: 400),
      verify: (bloc) {
        expect(bloc.state, isNot(isA<AudioRecordingState$Recording>()));
      },
    );
  });
}
