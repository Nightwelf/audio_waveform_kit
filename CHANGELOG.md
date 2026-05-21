## 1.0.0

### Features

- **`AudioWaveformScope`** — DI-scope виджет; оборачивает дерево и предоставляет `AudioRecordingService`, `SpectrumAnalyzer` и `AudioRecordingBloc`
- **`AudioRecordButton`** — кнопка записи/остановки с фабричным конструктором `defaultStyle()`
- **`RecordingTimer`** — отображение прошедшего времени записи
- **`AudioWaveformPlayer`** — самодостаточный виджет воспроизведения с прогресс-баром; работает с файлом (native) и WAV-байтами (web)

#### Визуализация (live, во время записи)

- **`WaveformDisplay`** — огибающая волновой формы; стили `WaveformStyle.envelope` и `WaveformStyle.string`
- **`MessengerWaveformDisplay`** — RMS-волновая форма в стиле мессенджера
- **`RecordingLevelDisplay`** — VU-метр реального времени
- **`LiveSpectrumDisplay`** — живой FFT-спектр, обновляется каждые 50 мс
- **`StringSnapshotDisplay`** — осциллограф из сырых PCM-семплов

#### Визуализация (static, после записи)

- **`SpectrumDisplay`** — FFT-спектр; линейный и логарифмический режимы
- **`TimelineSpectrumDisplay`** — тепловая карта время–частота
- **`StaticLevelDisplay`** — статический VU-метр
- **`StaticMessengerWaveformDisplay`** — статическая RMS-волновая форма
- **`StaticStringSnapshotDisplay`** — статическая осциллограмма

#### BLoC и состояния

- **`AudioRecordingBloc`** — конечный автомат записи: `$Idle → $Recording → $Finished / $Error`; события `$Start`, `$Stop`, `$Reset`
- **`AudioPlayerBloc`** — конечный автомат воспроизведения: `$Idle / $Playing / $Paused / $Completed / $Error`; события `$Play`, `$Pause`, `$Stop`, `$Seek`

#### Анализ и модели

- **`SpectrumAnalyzer`** — чистый Dart FFT с оконной функцией Ханна, 50 % перекрытием, авто-нормализацией; методы `analyze()`, `computeTimeline()`, `analyzeRaw()`
- **`SpectrumConfig`** — настройки FFT: `fftSize`, `frequencyBands`, `frequencyMin/Max`, `sampleRate`, `dynamicRangeDb`, `displayType`
- **`RecordingResult`** — контейнер результата: `filePath`, `wavBytes`, `duration`, `waveformSamples`, `rmsSamples`, `snapshotSamples`, `spectrumData`, `spectrumTimeline`

#### Утилиты

- **`AudioUtils`** — `encodeWav()`, `wavToSamples()`, `formatDuration()`
- **`PlatformUtils`** — `isWeb`, `hasMicrophonePermission()`

### Platform support

| Platform | Recording     | Playback      |
|----------|---------------|---------------|
| Android  | ✓ file        | ✓ file        |
| iOS      | ✓ file        | ✓ file        |
| macOS    | ✓ file        | ✓ file        |
| Windows  | ✓ file        | ✓ file        |
| Linux    | ✓ file        | ✓ file        |
| Web      | ✓ WAV bytes   | ✓ WAV bytes   |
