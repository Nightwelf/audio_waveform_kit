# audio_waveform_kit

A Flutter package for audio recording with real-time waveform and spectrum visualization.

## Features

- **Record audio** from the microphone with a single tap
- **Real-time waveform** — scrolling bar history during recording
- **Real-time spectrum** — FFT-based frequency display (pure Dart, no native libraries)
- **Oscilloscope view** — raw PCM snapshot for signal inspection
- **Static visualizations** — replay waveform, spectrum, and timeline after recording
- **Playback widget** — progress bar + seek support out of the box
- **BLoC-based** — predictable state machine, easy to integrate with existing BLoC apps

## Getting started

Add to `pubspec.yaml`:

```yaml
dependencies:
  audio_waveform_kit: ^1.0.0
```

### Permissions

**Android** — `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

**iOS** — `Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Recording voice messages</string>
```

**macOS** — `macos/Runner/DebugProfile.entitlements` and `Release.entitlements`:
```xml
<key>com.apple.security.device.audio-input</key>
<true/>
```

## Usage

### 1. Wrap with `AudioWaveformScope`

```dart
AudioWaveformScope(
  // optional — all params have sensible defaults
  spectrumConfig: SpectrumConfig(fftSize: 1024, frequencyBands: 64),
  maxWaveformSamples: 56,
  maxSnapshotSamples: 2048,
  child: MyScreen(),
)
```

`AudioWaveformScope` provides `AudioRecordingService`, `SpectrumAnalyzer`, and `AudioRecordingBloc` to the subtree.

To plug in your own capture implementation — streaming PCM to disk instead of
buffering it in memory, recording from a foreground service, a custom file
location — pass `recordingService`:

```dart
AudioWaveformScope(
  recordingService: MyDiskStreamingRecordingService(),
  child: MyScreen(),
)
```

The scope then uses that instance as-is and does **not** dispose it — its
lifecycle is yours. Omit the parameter and the scope creates and owns an
`AudioRecordingServiceImpl` as before.

### 2. Add a record button

Use the built-in round button:

```dart
AudioRecordButton.defaultStyle(
  size: 72,
  recordingColor: Colors.red,   // optional
  idleColor: Colors.blue,       // optional
  onRecordingFinished: (RecordingResult result) {
    // available on all platforms:
    print(result.duration);           // Duration
    print(result.spectrumData);       // List<double> — FFT bins (dB)
    print(result.spectrumTimeline);   // List<List<double>> — frames × bands
    print(result.waveformSamples);    // List<double>
    print(result.rmsSamples);         // List<double>

    if (kIsWeb) {
      // result.wavBytes — Uint8List with full WAV file contents
      // result.filePath — generated key, not a real path on web
    } else {
      // result.filePath — absolute path to the saved .wav file
    }
  },
)
```

Or pass any widget via `builder` — receives `isRecording` and `onTap`:

```dart
AudioRecordButton(
  onRecordingFinished: (result) { … },
  builder: ({required context, required isRecording, required onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 72,
        height: 72,
        color: isRecording ? Colors.red : Colors.blue,
        child: Icon(isRecording ? Icons.stop : Icons.mic),
      ),
    );
  },
)
```

### 3. Show live visualizations during recording

```dart
// Scrolling amplitude bars
WaveformDisplay()

// Current level meter
RecordingLevelDisplay()

// FFT spectrum
LiveSpectrumDisplay()

// Oscilloscope (raw PCM)
StringSnapshotDisplay()

// Elapsed time
RecordingTimer()
```

### 4. Show static visualizations after recording

These widgets read directly from `AudioRecordingBloc` — no props needed:

```dart
// Averaged spectrum
SpectrumDisplay()

// Spectrum over time (heatmap-style)
TimelineSpectrumDisplay()

// Messenger-style waveform (RMS per window)
StaticMessengerWaveformDisplay(samples: state.rmsSamples)

// Oscilloscope snapshot
StaticStringSnapshotDisplay()
```

Or access the data directly from the callback result:

```dart
onRecordingFinished: (result) {
  // result.spectrumData, result.spectrumTimeline, result.waveformSamples …
}
```

### 5. Play back the recorded file

```dart
// from callback:
AudioWaveformPlayer(filePath: result.filePath)

// or from bloc state:
final state = context.read<AudioRecordingBloc>().state as AudioRecordingState$Finished;
AudioWaveformPlayer(filePath: state.filePath)
```

`AudioWaveformPlayer` is self-contained — it manages its own `AudioPlayerBloc` and does **not** require `AudioWaveformScope`.

## Recording state machine

```
Idle → [Start] → Recording → [Stop] → Finished
                            → [error] → Error
     ← [Reset] ←─────────────────────────────
```

| State | Notable fields |
|-------|----------------|
| `AudioRecordingState$Idle` | — |
| `AudioRecordingState$Recording` | `duration`, `waveformSamples`, `rmsSamples`, `snapshotSamples`, `liveSpectrumData` |
| `AudioRecordingState$Finished` | `filePath`, `wavBytes` (web only), `duration`, `waveformSamples`, `rmsSamples`, `snapshotSamples`, `spectrumData`, `spectrumTimeline` |
| `AudioRecordingState$Error` | `message` |

## Level scale

`StringSnapshotDisplay`, `WaveformDisplay` (envelope style), `RecordingLevelDisplay`
and `StaticLevelDisplay` all size themselves the same way: RMS level of the
signal mapped logarithmically onto `floorDb`…`ceilingDb`. A linear gain cannot
show both room noise and speech — they sit 30–40 dB apart, so one multiplier
either buries the noise at zero or clips speech at the edge of the box.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `floorDb` | `-55.0` | RMS level at which the display is empty/flat — anything quieter is silence |
| `ceilingDb` | `-15.0` | RMS level at which the display reaches full size |

`MessengerWaveformDisplay` (live) uses the same idea via `logarithmic: true` and
`minDbThreshold` (equivalent to `floorDb`, `ceilingDb` fixed at `0`).

## Oscilloscope tuning

`StringSnapshotDisplay` and `StaticStringSnapshotDisplay` draw raw PCM, so the
defaults matter. The swing of the string comes from the signal level on a dB
scale, the wave shape is normalized separately — a linear gain cannot show both
room noise and speech, they are 30–40 dB apart.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `floorDb` | `-55.0` | RMS level at which the string lies flat — anything quieter is silence |
| `ceilingDb` | `-15.0` | RMS level at which the string swings across the whole box |
| `pointSpacing` | `3.0` | Logical pixels per drawn point; samples in between are averaged (low-pass). `0` draws every sample |
| `alignToZeroCrossing` | `true` | Starts the curve at a rising zero crossing so the wave does not slide horizontally |
| `minAmplitudeFraction` | `0.02` | Peak below this draws a flat resting string, before the level is even measured |
| `autoGain` | `false` | Legacy per-frame peak normalization — quiet noise fills the whole box and the string jumps between frames |
| `maxGain` | `12.0` | Upper bound for `autoGain` amplification |

Too still while talking — raise `floorDb` (`-45`) or lower `ceilingDb` (`-20`).
Too lively while silent — lower `floorDb` (`-65`).
Pre-1.3 look: `autoGain: true, pointSpacing: 0, alignToZeroCrossing: false`.

## SpectrumConfig

| Parameter | Default | Description |
|-----------|---------|-------------|
| `fftSize` | `1024` | FFT window size (power of 2) |
| `frequencyBands` | `64` | Number of output frequency bins |
| `frequencyMin` | `20` | Lower frequency limit (Hz) |
| `frequencyMax` | `20000` | Upper frequency limit (Hz) |
| `sampleRate` | `44100` | Input sample rate (Hz) |
| `dynamicRangeDb` | `60.0` | dB range shown; lower = fewer but louder bars |
| `displayType` | `linear` | `linear` or `logarithmic` frequency scale |

## Running the example

```sh
cd example && flutter run -d linux
# or
cd example && flutter run -d chrome
```

## Dependencies

| Package | Purpose |
|---------|---------|
| `record` | Microphone capture (PCM stream) |
| `audioplayers` | Playback |
| `flutter_bloc` + `bloc_concurrency` | State management |
| `equatable` | Value equality |
| `path_provider` | Temporary file storage |