# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Build & Test

| Command | Purpose |
|---------|---------|
| `flutter analyze` | Static analysis |
| `flutter test` | Run all unit tests |
| `flutter test test/spectrum_analyzer_test.dart` | Run a single test file |
| `flutter format lib test example/lib` | Format code |
| `cd example && flutter run -d linux` | Run the example app on Linux |
| `cd example && flutter run -d chrome` | Run the example app on Web |

---

## Package Overview

`voice_message` is a Flutter package providing audio recording with real-time waveform/spectrum visualization. The public API is `lib/voice_message.dart`.

**Key dependencies:** `record` (mic capture), `audioplayers` (playback), `flutter_bloc` + `bloc_concurrency`, `equatable`.

**FFT is implemented in pure Dart** (`SpectrumAnalyzer`) — no external FFT library.

---

## Architecture

### Entry Point: `VoiceMessageScope`

Wrap the widget tree with `VoiceMessageScope` to provide DI for recording:

```dart
VoiceMessageScope(
  spectrumConfig: SpectrumConfig(fftSize: 1024, frequencyBands: 64),
  maxWaveformSamples: 100,
  maxSnapshotSamples: 2048,
  child: ...,
)
```

It provides via `RepositoryProvider`: `AudioRecordingService`, `SpectrumAnalyzer`  
And via `BlocProvider`: `AudioRecordingBloc`

`AudioPlayerBloc` is **not** in the scope — it is self-managed inside `VoiceMessagePlayer` per file.

---

### Recording State Machine (`AudioRecordingBloc`)

```
Idle → [Start] → Recording → [Stop] → Finished
                           → [error] → Error
      ← [Reset] ←──────────────────────────────
```

| State | Key fields |
|-------|-----------|
| `$Idle` | — |
| `$Recording` | `duration`, `waveformSamples`, `snapshotSamples`, `liveSpectrumData` |
| `$Finished` | `filePath`, `duration`, `waveformSamples`, `snapshotSamples`, `spectrumData`, `spectrumTimeline` |
| `$Error` | `message` |

---

### PCM Data Flow

The recording service streams **PCM16LE bytes at 44100 Hz** from the mic. The bloc processes each chunk:

1. **Waveform** — every 441st sample → `waveformSamples` (rolling window, max `maxWaveformSamples`)
2. **Snapshot** — all raw samples → `snapshotSamples` (rolling window, max `maxSnapshotSamples`), for oscilloscope-style display
3. **Live spectrum** — `SpectrumAnalyzer.analyzeRaw(snapshotSamples)` → `liveSpectrumData` (dB per FFT bin, updated every chunk)

On `Stop`, the full `recordedBytes` from `AudioRecordingServiceImpl` are passed to:
- `SpectrumAnalyzer.analyze()` → `spectrumData` (averaged, auto-normalized dB bins)
- `SpectrumAnalyzer.computeTimeline()` → `spectrumTimeline` (frames × bands matrix)

---

### Visualization Widgets

**Live (during recording) — require `VoiceMessageScope`:**
| Widget | Painter | Data source |
|--------|---------|-------------|
| `WaveformDisplay` | `WaveformPainter` | `waveformSamples` (rolling bar history) |
| `RecordingLevelDisplay` | `RecordingLevelPainter` | `waveformSamples` (current level) |
| `LiveSpectrumDisplay` | `SpectrumPainter` | `liveSpectrumData` |
| `StringSnapshotDisplay` | `StringSnapshotPainter` | `snapshotSamples` (oscilloscope) |

**Static (after recording — use `$Finished` state fields):**
| Widget | Painter | Data source |
|--------|---------|-------------|
| `SpectrumDisplay` | `SpectrumPainter` / `LogarithmicSpectrumPainter` | `spectrumData` |
| `TimelineSpectrumDisplay` | `TimelineSpectrumPainter` | `spectrumTimeline` |
| `StaticLevelDisplay` | `RecordingLevelPainter` | `waveformSamples` |
| `StaticStringSnapshotDisplay` | `StringSnapshotPainter` | `snapshotSamples` |

**Controls:**
- `AudioRecordButton` — tap to start/stop; calls `onRecordingFinished` on state `$Finished`
- `RecordingTimer` — displays elapsed duration from `$Recording.duration`
- `VoiceMessagePlayer` — self-contained playback widget, takes a `filePath`

---

### `SpectrumConfig`

Controls FFT behavior. Defaults: `fftSize=1024`, `sampleRate=44100`, `frequencyBands=64`, `frequencyMin=20`, `frequencyMax=20000`, `dynamicRangeDb=60`. Pass once to `VoiceMessageScope`; the bloc forwards it to `SpectrumAnalyzer`.

---

## Архитектурные ограничения

- **Структура фичи:** `{module}_scope.dart`, `config.dart`, `domain/`, `data/`, `presentation/`
- **Именование:** sealed variant — `$` суффикс; реализация — `Impl`; файлы — `snake_case`
- **DI:** `RepositoryProvider<Interface>` + `Impl` в `create:`; `dispose:` для стримов
- **BLoC:** `sealed` event/state, `part of` bloc; transformers: `restartable`/`droppable`/`sequential`

---

## Обязательные правила

1. Один виджет — один файл
2. BLoC: в state только публичные поля и getter, без логики
3. `dispose()` — для репозиториев со стримами и BLoC с `StreamSubscription`
4. `const` везде где возможно
5. Не `!` — проверять null
6. `context.read()` — вне build; в build — только `context.watch()`
7. Перед `setState()` в async-методах: `if (!mounted) return;`
8. Коллекции — `ListEquality`/`DeepCollectionEquality`, не `==`
9. Логика только в BLoC/Repository

---

## Reference

- Эталонная фича: `./lib/doc/example/`
- Codestyle (naming, BLoC, DI patterns): `./lib/doc/codestyle.md`