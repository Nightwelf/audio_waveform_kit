## 1.0.1

### Fixes

- **`AudioRecordingBloc`** — убран повторный `dispose()` `AudioRecordingService`: при демонтаже `AudioWaveformScope` сервис закрывался дважды (в `Bloc.close()` и в `RepositoryProvider.dispose`), что могло бросать исключение на уже освобождённом `AudioRecorder`. Теперь жизненным циклом сервиса управляет только DI-scope
- **`StringSnapshotPainter`** — исправлены `NaN`-координаты пути при снапшоте из одного сэмпла
- **`TimelineSpectrumPainter`** — исправлено деление на ноль при `SpectrumConfig.frequencyBands == 1`
- **`LiveSpectrumDisplay`**, **`SpectrumDisplay`** — чтение `spectrumConfig` в `build()` переведено с `context.read()` на `context.select()`
- **`AudioWaveformPlayer`** — убран небезопасный `context.findRenderObject()!` в пользу явной проверки на `null`
- **`WaveformDisplay`**, **`RecordingLevelDisplay`**, **`StringSnapshotDisplay`**, **`MessengerWaveformDisplay`**, **`LiveSpectrumDisplay`** — сравнение списков сэмплов в `buildWhen` переведено с `!=` (по ссылке) на `ListEquality` (по содержимому)
- `AudioRecordingBloc` — дефолт `maxSnapshotSamples` приведён к `2048`, согласован с дефолтом `AudioWaveformScope`

### Changes

- `WaveformStyle` перенесён из `widgets/waveform_display.dart` в `painters/waveform_painter.dart` — устранена обратная зависимость painter → widget; публичный API не изменился (`WaveformStyle` по-прежнему доступен из `audio_waveform_kit.dart`)
- Добавлен `AudioRecordingState$Finished.toRecordingResult()` — единая точка маппинга state в `RecordingResult` вместо ручной сборки в `AudioRecordButton`
- `collection` добавлен в прямые зависимости пакета (ранее использовался транзитивно)

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
