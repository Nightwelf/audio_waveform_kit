## 1.3.0

### Fixes

- **`AudioRecordingBloc`** — PCM с платформенного канала читался как `chunk.buffer.asInt16List()`: от начала буфера сообщения и на всю его длину, мимо `offsetInBytes` и длины самого чанка. В визуализацию и спектр уходили служебные байты сообщения и соседние куски, а при нечётном смещении PCM16 разъезжался на байт — любой звук превращался в шум почти полной громкости, одинаковый и в тишине, и под речь. На записанный файл это не влияло: сервис пишет чанк сам. Теперь `Int16List.sublistView(chunk)`, с копией при нечётном смещении
- **`AudioUtils.wavToSamples`** — та же ошибка в `wavBytes.buffer.asInt16List(44)`: для вью читались чужие байты
- **`StringSnapshotPainter`** — размах «струны» не зависел от громкости: каждый кадр нормировался на собственный пик (`scale = 1 / peak`), поэтому и тихий шум, и громкая речь рисовались во всю высоту. Теперь размах задаётся уровнем сигнала (RMS) по логарифмической шкале `floorDb`…`ceilingDb`: тишина — прямая линия, шум комнаты — мелкая дрожь, речь — полный размах. Линейного усиления нет: между шумом и речью 30–40 дБ, одним множителем оба конца шкалы не показать
- **`StringSnapshotPainter`** — форма волны нормируется отдельно от размаха, поэтому кривая больше не срезается по границе бокса
- **`StringSnapshotPainter`** — сырые сэмплы рисовались точка-в-сэмпл (2048 точек на ~360 px), на экране это полоса шума. Теперь усредняются до одной точки на `pointSpacing` логических пикселей; усреднение работает как ФНЧ
- **`StringSnapshotPainter`** — окно снапшота съезжало по фазе на каждый чанк, волна ползла по горизонтали. Добавлен триггер по переходу через ноль снизу вверх (`alignToZeroCrossing`); сдвиг берётся из запаса точек, поэтому горизонтальный масштаб не меняется от кадра к кадру
- **`StringSnapshotPainter`** — контрольной точкой квадратичной кривой брался предыдущий сэмпл вместо текущего: кривая шла на шаг позади данных, а последний сегмент проходил прямой хордой мимо предпоследней точки
- **`StringSnapshotPainter.shouldRepaint`** — сравнивал только `samples` и `stringColor`; смена остальных параметров не перерисовывала холст
- **`AudioRecordingBloc.waveformSamples`** — точки брались мгновенным отсчётом (каждый 441-й сэмпл): на самом громком слоге могла попасться фаза перехода через ноль и дать 0. Теперь это RMS-энергия по окнам ~10 мс — честная огибающая, неотрицательные значения. Окно RMS также было захардкожено под 44100 Гц (441 сэмпл); теперь считается от `spectrumConfig.sampleRate`, а остаток окна переносится через границу чанка вместо того, чтобы теряться
- **`RecordingLevelPainter`** — высота столбика бралась из мгновенного отсчёта линейно; после смены семантики `waveformSamples` (см. выше) индикатор всегда выглядел почти пустым на речи (−22 dBFS RMS = 8% высоты). Теперь высота — по той же логарифмической шкале `floorDb`/`ceilingDb`, что и у струны
- **`RecordingLevelPainter.shouldRepaint`** — сравнивал только `samples` и `barColor`; `barSpacing`, `minBarHeightFraction` и новые `floorDb`/`ceilingDb` не перерисовывали холст
- **`WaveformPainter`** (`WaveformStyle.envelope`) — каждый кадр нормировался на собственный пик (`scale = 1 / peak`), та же болезнь, что была у струны: тишина и речь рисовались во всю высоту. Теперь размах — по логарифмической шкале `floorDb`/`ceilingDb`
- **`WaveformDisplay`** (`WaveformStyle.string`) — рисовал дубль струны на 56 децимированных, после смены семантики `waveformSamples` уже неотрицательных (знака нет) отсчётах. Теперь при `style: WaveformStyle.string` рендерится `StringSnapshotDisplay` — он читает полные `snapshotSamples` и уже умеет форму, размах и триггер по нулю
- **`MessengerWaveformDisplay`** (живой виджет) — дефолт `logarithmic: false` (нормировка на глобальный пик) на скроллящемся окне прыгал на каждом кадре, а без окна один громкий всплеск пережимал всё, что было до него. Дефолт изменён на `logarithmic: true`. `StaticMessengerWaveformDisplay` (весь клип целиком) не тронут — пиковая нормировка там осознанный «телеграмный» вид
- **`MessengerWaveformPainter.shouldRepaint`** — не сравнивал `silenceThreshold`, `minDbThreshold`, `barSpacing`

### Changes

- **`StringSnapshotDisplay`**, **`StaticStringSnapshotDisplay`**, **`StringSnapshotPainter`** — новые параметры `floorDb`, `ceilingDb`, `autoGain`, `maxGain`, `pointSpacing`, `alignToZeroCrossing`. Сигнатуры совместимы, но вид по умолчанию изменился. Прежний возвращается комбинацией `autoGain: true, pointSpacing: 0, alignToZeroCrossing: false`
- **`RecordingLevelDisplay`**, **`StaticLevelDisplay`**, **`RecordingLevelPainter`** — новые параметры `floorDb` (`-55.0`), `ceilingDb` (`-15.0`)
- **`WaveformDisplay`**, **`WaveformPainter`** — новые параметры `floorDb` (`-55.0`), `ceilingDb` (`-15.0`) для `WaveformStyle.envelope`; для `WaveformStyle.string` игнорируются
- **`MessengerWaveformDisplay`** — дефолт `logarithmic` изменён с `false` на `true` (см. Fixes)
- dB-математика (`rmsOf`, `amplitudeForRms`) вынесена в один файл `lib/src/utils/level_scale.dart` — раньше жила отдельно в `StringSnapshotPainter` и дублировалась бы в `MessengerWaveformPainter`. Не экспортируется из `audio_waveform_kit.dart`, публичный API не растёт

## 1.2.0

### Features

- **`RmsBucketAccumulator`** экспортирован из `audio_waveform_kit.dart`: своя реализация `AudioRecordingService` может копить RMS-огибающую для хранения тем же алгоритмом, что и `AudioRecordingBloc`, не дублируя его

### Fixes

- **`AudioRecordingBloc`** — поток PCM, закрытый самим сервисом (остановка из уведомления foreground service, микрофон отобран системой), теперь переводит bloc в `Finished` так же, как `AudioRecordingEvent$Stop`. Раньше bloc оставался в `Recording` с тикающим таймером. Реакция на `onError` не изменилась

## 1.1.0

### Features

- **`AudioWaveformScope`** — опциональный параметр `recordingService`: позволяет подставить свою реализацию `AudioRecordingService` (например, пишущую PCM на диск по ходу записи вместо накопления в памяти, или работающую в foreground service) и при этом пользоваться виджетами и блоком пакета. При `null` поведение прежнее — scope сам создаёт `AudioRecordingServiceImpl` и освобождает его. Переданный извне сервис scope **не** диспозит: его жизненным циклом управляет вызывающая сторона

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
