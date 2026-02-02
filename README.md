# Hair Analysis & Filter Android App

An iOS-style hair analysis and filter application built with Jetpack Compose, using MediaPipe for real-time hair segmentation and face landmark detection.

## Features

- 🎥 **Real-time Camera** - Front camera with live hair and face detection
- 🎨 **Filter System** - 10+ predefined filters (Batman, Joker, Cyberpunk, etc.)
- 💇 **Hair Analysis** - AI-powered hair type, texture, and color detection
- 🌈 **Color Tools** - Custom hair colors with ombre/balayage support
- ✂️ **Style Simulations** - Hair length, bangs, and accessories
- 📸 **Before/After Comparison** - Interactive slider for comparing results
- 📱 **Photo History** - Save, share, and manage your looks
- 🔒 **100% On-Device** - All processing happens locally, no cloud dependencies

## Tech Stack

- **UI**: Jetpack Compose with Material 3
- **Architecture**: MVI + Clean Architecture
- **Camera**: CameraX (Preview, ImageAnalysis)
- **ML/AI**: MediaPipe (Hair Segmentation, Face Landmarks)
- **DI**: Koin
- **Async**: Kotlin Coroutines & Flow
- **Navigation**: Navigation Compose
- **Image**: Coil for image loading

## Requirements

- Android Studio Hedgehog (2023.1.1) or later
- JDK 11 or higher
- Android SDK 36
- Minimum SDK: 33 (Android 13)
- Target SDK: 36 (Android 14)

## Getting Started

### 1. Clone the Repository

```bash
git clone <repository-url>
cd NativeLocal_SLM_App
```

### 2. Add MediaPipe Models (Required)

Download and place MediaPipe model files in `app/src/main/assets/`:

- **Hair Segmenter**: `hair_segmenter.tflite`
  - Download from: [MediaPipe Image Segmenter](https://developers.google.com/mediapipe/solutions/vision/image_segmenter)

- **Face Landmarker**: `face_landmarker.tflite`
  - Download from: [MediaPipe Face Landmarker](https://developers.google.com/mediapipe/solutions/vision/face_landmarker)

### 3. Add Filter Assets (Optional)

For filter functionality, add PNG image assets in `app/src/main/assets/filters/`:

```
filters/
├── face/
│   ├── batman/
│   │   ├── mask.png
│   │   ├── eyes.png
│   │   └── metadata.json
│   └── joker/
│       ├── mask.png
│       ├── eyes.png
│       └── metadata.json
├── hair/
│   └── punk_mohawk/
│       └── hair_overlay.png
└── combo/
    └── wonder_woman/
        ├── mask.png
        ├── eyes.png
        └── hair_overlay.png
```

### 4. Build and Run

```bash
# Build debug APK
./gradlew assembleDebug

# Install on connected device
adb install -r app/build/outputs/apk/debug/app-debug.apk

# Or run directly from Android Studio
# Click Run > Run 'app'
```

## Development

### Build Commands

```bash
# Clean build
./gradlew clean

# Build debug
./gradlew assembleDebug

# Build release
./gradlew assembleRelease

# Run unit tests
./gradlew test

# Run instrumented tests
./gradlew connectedAndroidTest

# Run all tests
./gradlew check
```

### Testing

```bash
# Run unit tests with coverage
./gradlew test jacocoTestReport

# View coverage report
open app/build/reports/jacoco/test/html/index.html
```

## Project Structure

```
app/src/main/
├── assets/              # MediaPipe models and filter assets
├── java/.../
│   ├── data/           # Data layer (repositories, models)
│   ├── domain/         # Domain layer (use cases, models)
│   ├── presentation/   # UI layer (screens, viewmodels)
│   └── ui/             # Theme, components, animations
└── res/                # Android resources
```

## Architecture

```
UI Layer (Compose)
    ↓
ViewModels (MVI)
    ↓
Use Cases
    ↓
Repositories
    ↓
MediaPipe / Data Sources
```

## Key Files

- `MainActivity.kt` - Main entry point with navigation
- `MediaPipeHairRepository.kt` - MediaPipe integration
- `CameraViewModel.kt` - Camera state management
- `ApplyFilterUseCase.kt` - Filter application logic
- `OnboardingScreen.kt` - First-run experience

## Claude Memory Integration

This project uses [Claude Memory](https://docs.claude-mem.ai) for cross-session context persistence. Historical context about bugs, features, and architectural decisions is automatically injected into new sessions to maintain continuity.

### Features

- **Automatic Capture**: All file reads, edits, and tool executions are tracked
- **AI-Powered Summaries**: Context is compressed into structured observations
- **Smart Injection**: Relevant historical context is included in new sessions
- **Efficient Retrieval**: Searchable database with natural language queries
- **Android-Optimized**: Configured with Android-specific observation types and concepts

### Quick Setup

1. Install the claude-mem plugin:
   ```bash
   claude plugin marketplace add thedotmack/claude-mem
   claude plugin install claude-mem
   ```

2. Get an OpenRouter API key from https://openrouter.ai/ (free tier available)

3. Configure the API key (see [docs/CLAUDE_MEMORY_SETUP.md](docs/CLAUDE_MEMORY_SETUP.md))

4. Restart Claude Code - memory is now active!

### Usage

Memory works automatically - no manual intervention required. In future sessions, you'll see context like:

```
📊 Memory: 23 observations (7,145 tokens)
⚡ Worker: 3,512 tokens in 0.3s
💾 Saved: ~3,633 tokens (34% reduction)

Recent Work:
• [#1234] Configured OpenRouter API with GLM 4.5 Air
• [#1235] Added Android-specific observation types
• [#1236] Created PROJECT_CONTEXT.md with architecture details
```

**See**: [docs/CLAUDE_MEMORY_SETUP.md](docs/CLAUDE_MEMORY_SETUP.md) for complete setup guide

## Documentation

- [Implementation Summary](IMPLEMENTATION_SUMMARY.md) - Complete implementation details
- [E2E Test Scenarios](E2E_TEST_SCENARIOS.md) - End-to-end testing guide
- [CLAUDE.md](CLAUDE.md) - Project instructions for AI assistants
- [Claude Memory Setup](docs/CLAUDE_MEMORY_SETUP.md) - Memory system configuration guide

## Performance Targets

- Camera preview: 25-30 FPS
- Filter application: < 100ms latency
- Memory usage: < 300MB
- No ANRs or crashes

## Pass Conditions

1. **100% Code Coverage** - Verified via JaCoCo
2. **All E2E Tests Pass** - All 5 scenarios pass on target device

## License

This project is part of the NativeLocal_SLM_App implementation.

## Contributing

This is a complete implementation following the detailed plan in [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md).

## Support

For issues or questions, refer to:
- [E2E_TEST_SCENARIOS.md](E2E_TEST_SCENARIOS.md) for debugging
- [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) for architecture details
