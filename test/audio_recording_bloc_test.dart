import 'dart:async';
import 'dart:typed_data';

import 'package:audio_waveform_kit/src/controllers/audio_recording_bloc.dart';
import 'package:audio_waveform_kit/src/models/spectrum_config.dart';
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
      'finishes when the service closes the stream on its own',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const AudioRecordingEvent$Start());
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await service.controller.close();
        await Future<void>.delayed(const Duration(milliseconds: 200));
      },
      verify: (bloc) {
        expect(bloc.state, isA<AudioRecordingState$Finished>());
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

    // Регрессия: чанк с платформенного канала приходит вью в буфер сообщения.
    // Чтение через `chunk.buffer` брало чужие байты, а при нечётном смещении
    // разъезжало PCM16 на байт — звук превращался в шум полной громкости.
    for (final offset in [4, 5]) {
      test('снапшот читает вью со смещением $offset, а не весь буфер',
          () async {
        const pcm = [3277, -6554, 9830, -13107];
        final payload = Uint8List.sublistView(Int16List.fromList(pcm));
        final host = Uint8List(offset + payload.length + 3)
          ..fillRange(0, offset + payload.length + 3, 0xAA)
          ..setRange(offset, offset + payload.length, payload);
        final chunk = Uint8List.sublistView(
          host,
          offset,
          offset + payload.length,
        );

        final bloc = buildBloc()..add(const AudioRecordingEvent$Start());
        await Future<void>.delayed(const Duration(milliseconds: 30));
        service.controller.add(chunk);
        await Future<void>.delayed(const Duration(milliseconds: 30));

        final state = bloc.state;
        expect(state, isA<AudioRecordingState$Recording>());
        expect(
          (state as AudioRecordingState$Recording).snapshotSamples,
          [for (final s in pcm) s / 32768],
        );

        await bloc.close();
      });
    }

    blocTest<AudioRecordingBloc, AudioRecordingState>(
      'waveformSamples — RMS поданного окна (константа даёт RMS, равный себе)',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const AudioRecordingEvent$Start());
        await Future<void>.delayed(const Duration(milliseconds: 30));
        const sampleValue = 16384; // 0.5 после нормализации на kInt16Scale
        service.controller.add(
          Uint8List.sublistView(
            Int16List.fromList(List<int>.filled(441, sampleValue)),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
      },
      verify: (bloc) {
        final state = bloc.state as AudioRecordingState$Recording;
        expect(state.waveformSamples, isNotEmpty);
        expect(state.waveformSamples.every((s) => s >= 0), isTrue);
        expect(state.waveformSamples, everyElement(closeTo(0.5, 1e-9)));
      },
    );

    test('размер RMS-окна следует spectrumConfig.sampleRate', () async {
      final bloc = AudioRecordingBloc(
        recordingService: service,
        spectrumAnalyzer: SpectrumAnalyzer(),
        spectrumConfig: const SpectrumConfig(sampleRate: 16000),
      )..add(const AudioRecordingEvent$Start());
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // 16000 / 100 = 160 сэмплов на окно — ровно одно завершённое окно.
      service.controller.add(
        Uint8List.sublistView(Int16List.fromList(List<int>.filled(160, 1000))),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final state = bloc.state as AudioRecordingState$Recording;
      expect(state.waveformSamples, hasLength(1));

      await bloc.close();
    });

    test('остаток окна переносится через границу чанка', () async {
      final bloc = AudioRecordingBloc(
        recordingService: service,
        spectrumAnalyzer: SpectrumAnalyzer(),
        spectrumConfig: const SpectrumConfig(sampleRate: 16000),
      )..add(const AudioRecordingEvent$Start());
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // То же окно в 160 сэмплов, разрезанное на два чанка по 80.
      service.controller.add(
        Uint8List.sublistView(Int16List.fromList(List<int>.filled(80, 1000))),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      service.controller.add(
        Uint8List.sublistView(Int16List.fromList(List<int>.filled(80, 1000))),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final state = bloc.state as AudioRecordingState$Recording;
      expect(state.waveformSamples, hasLength(1));

      await bloc.close();
    });
  });
}
