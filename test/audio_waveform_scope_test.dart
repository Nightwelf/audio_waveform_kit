import 'dart:async';
import 'dart:typed_data';

import 'package:audio_waveform_kit/src/audio_waveform_scope.dart';
import 'package:audio_waveform_kit/src/services/audio_recording_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Подделка сервиса записи: запоминает факт освобождения.
class FakeAudioRecordingService implements AudioRecordingService {
  bool disposed = false;

  @override
  Future<Stream<Uint8List>> startStream() async => const Stream.empty();

  @override
  Future<String> stop() async => '/tmp/fake_vm.wav';

  @override
  Uint8List get recordedBytes => Uint8List(0);

  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  group('AudioWaveformScope.recordingService', () {
    testWidgets('injected service is provided to the subtree', (tester) async {
      final service = FakeAudioRecordingService();
      late AudioRecordingService provided;

      await tester.pumpWidget(
        AudioWaveformScope(
          recordingService: service,
          child: Builder(
            builder: (context) {
              provided = context.read<AudioRecordingService>();
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(identical(provided, service), isTrue);
    });

    testWidgets('injected service is not disposed by the scope',
        (tester) async {
      final service = FakeAudioRecordingService();

      await tester.pumpWidget(
        AudioWaveformScope(
          recordingService: service,
          child: const SizedBox.shrink(),
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());

      expect(service.disposed, isFalse);
    });

    testWidgets('provides its own service when none is passed',
        (tester) async {
      late AudioRecordingService provided;

      await tester.pumpWidget(
        AudioWaveformScope(
          child: Builder(
            builder: (context) {
              provided = context.read<AudioRecordingService>();
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(provided, isA<AudioRecordingService>());
    });
  });
}
