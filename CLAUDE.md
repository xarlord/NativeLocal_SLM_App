# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

NativeLocal_SLM_App is a hair analysis and filter Android application built with Jetpack Compose using Kotlin. The app uses MediaPipe for real-time hair segmentation and face landmark detection to provide virtual hair color/style try-on, hair analysis with recommendations, and real-time filter effects.

- **Package**: `com.example.nativelocal_slm_app`
- **Minimum SDK**: 24 (Android 7.0)
- **Target SDK**: 36
- **Compile SDK**: 36
- **Architecture**: MVI + Use Cases with clean architecture layers

### Key Features
- Front camera with real-time hair segmentation and face landmark detection (MediaPipe)
- iOS-style UI with immersive camera experience
- Pre-designed filters (Batman, Joker, hairstyles, etc.) with overlay system
- Hair color tools (custom colors, ombre/balayage, extraction from photos)
- Style simulations (length adjustment, bangs, volume, accessories)
- Before/after comparison slider and photo history sharing
- 100% on-device processing (no cloud dependencies)

## Build System

This project uses Gradle with Kotlin DSL (`.kts` files) and version catalog via `gradle/libs.versions.toml`.

### Common Commands

Build the project:
```bash
./gradlew build
```

On Windows (use this wrapper):
```bash
gradlew.bat build
```

Build debug APK:
```bash
./gradlew assembleDebug
```

Build release APK:
```bash
./gradlew assembleRelease
```

Run unit tests with coverage:
```bash
./gradlew test jacocoTestReport
```

Run instrumented tests (requires connected device or emulator):
```bash
./gradlew connectedAndroidTest
```

Run all tests (unit + instrumented):
```bash
./gradlew check
```

Run a specific unit test class:
```bash
./gradlew test --tests com.example.nativelocal_slm_app.ExampleUnitTest
```

Clean build outputs:
```bash
./gradlew clean
```

Install debug build to connected device:
```bash
./gradlew installDebug
```

Install and run on connected device:
```bash
./gradlew installDebug && adb shell am start -n com.example.nativelocal_slm_app/.MainActivity
```

### Testing Commands

Install debug APK with ADB:
```bash
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

Monitor logs:
```bash
adb logcat -c && adb logcat | grep -E "NativeLocal_SLM_App|MediaPipe|Performance"
```

Check performance metrics:
```bash
adb shell dumpsys gfxinfo com.example.nativelocal_slm_app
adb shell dumpsys meminfo com.example.nativelocal_slm_app
```

## Architecture

### Layer Structure
```
UI Layer (Compose) → ViewModels → Use Cases → Repository → MediaPipe
```

### Module Structure
```
app/src/main/java/com/example/nativelocal_slm_app/
├── data/
│   ├── repository/          # Repository implementations
│   │   ├── MediaPipeHairRepository.kt    # MediaPipe integration
│   │   └── FilterAssetsRepository.kt     # Filter asset loading
│   ├── source/local/        # Local data sources
│   └── model/               # Data models (HairAnalysisResult, FilterEffect, SavedLook)
├── domain/
│   ├── usecase/             # Business logic use cases
│   │   ├── ProcessCameraFrameUseCase.kt
│   │   ├── AnalyzeHairUseCase.kt
│   │   ├── ApplyFilterUseCase.kt
│   │   └── SaveLookUseCase.kt
│   ├── model/               # Domain models (HairType, HairColor, FilterCategory)
│   └── repository/          # Repository interfaces
├── presentation/
│   ├── camera/              # Camera screen and preview
│   ├── onboarding/          # Onboarding flow
│   ├── filters/             # Filter selection and adjustments
│   ├── results/             # Results, before/after, history
│   └── di/                  # Dependency injection (Koin modules)
├── ui/
│   ├── theme/               # iOS-style theme (Color, Type, Theme)
│   ├── components/          # Reusable UI components (BottomSheet, iOSButton)
│   └── animation/           # Spring animations and transitions
└── MainActivity.kt
```

### Key Technologies
- **UI**: Jetpack Compose with Material 3
- **Camera**: CameraX (Preview, ImageAnalysis)
- **ML/AI**: MediaPipe (Hair Segmentation, Face Landmarks)
- **DI**: Koin
- **Async**: Kotlin Coroutines & Flow
- **Image**: Coil for image loading
- **Testing**: JUnit 4, AndroidX Test, JaCoCo for coverage

### UI Design Principles (iOS-Style)
- Typography: SF Pro-like font stack (LargeTitle 34sp, Title1 28sp, Body 17sp)
- Buttons: Pill-shaped, 48dp height, haptic feedback
- Bottom sheets: 16dp corner radius, backdrop blur, spring animations
- Color picker: Circular swatches (48dp), selected scale (1.2x)
- Immersive camera: Edge-to-edge, minimal floating controls
- Animations: Spring physics (stiffness = 300f, damping = 30f)

## Asset Structure

### MediaPipe Models
```
app/src/main/assets/
├── hair_segmenter.tflite
└── face_landmarker.tflite
```

### Filter Assets
```
app/src/main/assets/filters/
├── face/                    # Face makeup filters
│   ├── batman/
│   │   ├── mask.png
│   │   ├── eyes.png
│   │   └── metadata.json
│   ├── joker/
│   ├── skeleton/
│   └── tiger_face/
├── hair/                    # Hair overlay filters
│   ├── punk_mohawk/
│   ├── neon_glow/
│   └── fire_hair/
└── combo/                   # Combined face + hair filters
    ├── wonder_woman/
    ├── harley_quinn/
    └── cyberpunk/
```

## Configuration Files

- **build.gradle.kts** (root): Project-level build configuration, applies plugins via version catalog
- **app/build.gradle.kts**: Module-level build config with namespace, SDK versions, build types, and dependencies
- **settings.gradle.kts**: Repository configuration (Google, MavenCentral) and module inclusion
- **gradle/libs.versions.toml**: Version catalog for dependency and plugin management
- **gradle.properties**: JVM args (`-Xmx2048m`), AndroidX enabled, Kotlin code style set to "official"
- **app/proguard-rules.pro**: ProGuard rules for MediaPipe and optimization

## Development Notes

- All Kotlin source files use the official Kotlin code style
- The project uses non-transitive R classes to reduce R class size
- Edge-to-edge display is enabled by default in MainActivity
- Dynamic theming is automatic on Android 12+ devices via Material 3
- **Pass Condition 1**: 100% code coverage required (measured via JaCoCo)
- **Pass Condition 2**: All E2E tests must pass on target device

## Performance Requirements

- Camera preview: 25-30 FPS
- Filter application: < 100ms latency
- Memory usage: < 300MB
- No ANRs or crashes during normal usage
- Process every 2nd frame for UI (15fps), every frame for capture

## Key Implementation Files

When working on specific features:

**Camera & MediaPipe:**
- `data/repository/MediaPipeHairRepository.kt` - MediaPipe integration
- `presentation/camera/CameraViewModel.kt` - Camera state management
- `presentation/camera/CameraPreview.kt` - CameraX preview composable

**Filter System:**
- `data/model/FilterEffect.kt` - Filter data models
- `domain/usecase/ApplyFilterUseCase.kt` - Filter application logic
- `presentation/filters/FilterSelectionSheet.kt` - Filter selection UI

**Testing:**
- `src/test/HairAnalysisEngineTest.kt` - Hair analysis unit tests
- `src/test/FilterComposerTest.kt` - Filter composition tests
- `src/androidTest/CameraIntegrationTest.kt` - Camera integration tests
- `src/androidTest/MediaPipeIntegrationTest.kt` - MediaPipe integration tests

## E2E Testing

E2E test scenarios are run manually on target device:
1. Happy Path - Basic Filter (onboarding → camera → filter → capture → save)
2. Color Change Workflow (color selection → real-time preview → save)
3. Before-After Comparison (slider functionality at different positions)
4. Memory Pressure Test (rapid photo capture, verify no OOM)
5. Camera Performance Test (FPS monitoring with complex filters)

Use debug build with StrictMode, LeakCanary, and MediaPipe verbose logging enabled for debugging.

## Pass Conditions

✅ **Pass Condition 1**: 100% code coverage verified via JaCoCo (`./gradlew test jacocoTestReport`)
✅ **Pass Condition 2**: All 5 E2E test scenarios pass on target device

Both conditions must be met before implementation is considered complete.

---

## Testing Progress (Current Session: 2026-02-01)

### Recent Achievements

**Test Infrastructure Status:**
- Total unit tests: 377 (372 passing, 5 failing)
- Total instrumented tests: 66 (all passing)
- Overall coverage: ~32% (target: 100% for non-instrumented code)

**Recently Completed Packages:**
- ✅ ui.theme (Color.kt, Type.kt) - 24 tests
- ✅ ui.animation (HairColorSwatch.kt) - 14 tests
- ✅ presentation.di (AppModule.kt) - 8 tests
- ✅ data.source.local (FilterAssetLoader.kt) - 24 tests
- ✅ domain.model (expanded) - 77 tests
- ✅ presentation.filters (instrumented) - 56 tests
- ✅ MainActivity (instrumented) - 10 tests

**Current Status:**
- Failing tests: 5 (domain.usecase with complex MediaPipe/Bitmap dependencies)
- Next priority: Move failing tests to androidTest (integration tests)
- Remaining work: UI components, repositories, onboarding UI

**Documentation:**
- See: `FINAL_COVERAGE_PROGRESS_SUMMARY.md`
- See: `QUICK_WINS_TEST_SUMMARY.md`
- See: `DOMAIN_MODEL_EXPANSION_SUMMARY.md`
- See: `FILTERS_TEST_SUMMARY.md`
