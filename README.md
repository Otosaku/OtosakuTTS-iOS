# OtosakuTTS-iOS

A Swift library for on-device text-to-speech synthesis using FastPitch and HiFiGAN models. Generate natural-sounding speech directly on iOS devices without any network connection or external API dependencies.

> [!IMPORTANT]
> ### 🚀 Successor project: LinnetTTS by VoxRT
> On-device TTS has moved to **[LinnetTTS](https://github.com/VoxRT/LinnetTTS)** — a ground-up
> rewrite on VoxRT's custom Rust inference runtime. Same idea as `OtosakuTTS`, but a new model
> (~41M params, 24 kHz) that streams audio from the first 80 ms and runs in real time on a single
> phone CPU core — and now beyond iOS:
>
> - **Code & SDKs →** [**VoxRT/LinnetTTS**](https://github.com/VoxRT/LinnetTTS) —
>   iOS Swift package, Android AAR, Linux C library, Python wheel.
> - **Weights & samples →** [**VoxRT/linnet-en-35m**](https://huggingface.co/VoxRT/linnet-en-35m) on Hugging Face,
>   plus a [demo Space](https://huggingface.co/spaces/VoxRT/linnet-tts).
>
> This repo stays up for reference, but new development happens in LinnetTTS. 👉 Start there.

## Features

- 🎯 **100% On-Device Processing** - All speech synthesis happens locally on your device
- 🚀 **Fast Generation** - Optimized CoreML models for quick audio generation
- 🔒 **Privacy-First** - No data leaves your device
- 📱 **iOS Native** - Built specifically for Apple platforms
- 🎵 **High Quality** - 22.05kHz sample rate with natural prosody

## Requirements

- iOS 15.0+ / macOS 12.0+
- Swift 5.7+
- Xcode 14.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/Otosaku/OtosakuTTS-iOS.git", from: "1.0.0")
]
```

Or in Xcode:
1. Go to File → Add Package Dependencies
2. Enter: `https://github.com/Otosaku/OtosakuTTS-iOS.git`
3. Select version 1.0.0 or later

## Model Setup

### Download Models

Download the required model archive from:
```
https://firebasestorage.googleapis.com/v0/b/my-project-1494707780868.firebasestorage.app/o/fastpitch_hifigan.zip?alt=media&token=d239c2de-fe93-460e-a1e4-044923a1be58
```

The archive contains:
- `FastPitch.mlmodelc` - Text-to-spectrogram model
- `HiFiGan.mlmodelc` - Spectrogram-to-audio vocoder
- `tokens.txt` - Phoneme token mappings
- `cmudict.json` - CMU pronunciation dictionary

### Extract Models

Extract the archive and ensure your directory structure looks like:
```
YourModelsDirectory/
├── FastPitch.mlmodelc/
├── HiFiGan.mlmodelc/
├── tokens.txt
└── cmudict.json
```

## Usage

### Basic Example

```swift
import OtosakuTTS_iOS
import AVFoundation

// Initialize TTS with path to models directory
let modelsURL = URL(fileURLWithPath: "/path/to/models")
let tts = try OtosakuTTS(modelDirectoryURL: modelsURL)

// Generate speech
let audioBuffer = try tts.generate(text: "Hello, world!")

// Play the audio
let audioEngine = AVAudioEngine()
let playerNode = AVAudioPlayerNode()

audioEngine.attach(playerNode)
audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: audioBuffer.format)
try audioEngine.start()

playerNode.scheduleBuffer(audioBuffer)
playerNode.play()
```

### Advanced Configuration

```swift
// Use specific compute units for performance tuning
let tts = try OtosakuTTS(
    modelDirectoryURL: modelsURL,
    computeUnits: .cpuAndGPU  // or .cpuOnly, .all
)
```

### Error Handling

```swift
do {
    let tts = try OtosakuTTS(modelDirectoryURL: modelsURL)
    let buffer = try tts.generate(text: inputText)
    // Use the buffer
} catch OtosakuTTSError.modelLoadingFailed(let model) {
    print("Failed to load \(model)")
} catch OtosakuTTSError.emptyInput {
    print("Please provide text to synthesize")
} catch {
    print("TTS Error: \(error)")
}
```

## Example App

Check out the [Example](Example/) directory for a complete iOS app demonstrating:
- Automatic model downloading and extraction
- Text input interface
- Audio playback
- Progress indicators
- Error handling

To run the example:
1. Open `Example/Example.xcodeproj`
2. Build and run
3. The app will automatically download models on first launch

## Architecture

The library uses a two-stage synthesis pipeline:

1. **FastPitch** - Converts text/phonemes to mel-spectrograms with pitch information
2. **HiFiGAN** - Converts spectrograms to high-quality audio waveforms

Both models run entirely on-device using CoreML for optimal performance.

## Current Limitations & Contributing

### Tokenizer Improvements Needed

The current tokenizer is quite basic and there's significant room for improvement in synthesis quality through better text processing. Current limitations include:

- Simple phoneme mapping without context awareness
- Limited handling of abbreviations and numbers
- Basic punctuation processing
- No support for emphasis or emotion markers

**We welcome contributors!** If you're interested in improving the tokenizer to enhance speech quality, please feel free to submit PRs or open issues with suggestions.

Areas for contribution:
- Better text normalization (numbers, dates, abbreviations)
- Context-aware phoneme selection
- Prosody prediction
- Multi-language support
- Custom pronunciation dictionaries

## Performance

Typical generation times on modern iOS devices:
- iPhone 14 Pro: ~0.5s for a typical sentence
- iPhone 12: ~0.8s for a typical sentence
- iPad Pro M2: ~0.3s for a typical sentence

Memory usage: ~200MB when models are loaded

## License

This project is available under the MIT license. See the LICENSE file for more info.

## Acknowledgments

- FastPitch and HiFiGAN model architectures by NVIDIA
- CMU Pronouncing Dictionary for phoneme mappings

## Support

For issues, questions, or suggestions, please open an issue on [GitHub](https://github.com/Otosaku/OtosakuTTS-iOS/issues).

---

Made with ❤️ for the iOS community
