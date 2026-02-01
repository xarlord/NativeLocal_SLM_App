# Developer Onboarding Checklist

## Project: NativeLocal_SLM_App

**Last Updated**: 2026-01-31
**Estimated Setup Time**: 30-45 minutes

---

## Prerequisites Checklist

Before starting, ensure you have:

- [ ] **GitHub account** with access to repository
- [ ] **Android Studio Hedgehog** (2023.1.1) or later installed
- [ ] **JDK 11** or higher installed
- [ ] **Android SDK 36** installed
- [ ] **Physical device or emulator** with Android 7.0 (API 24) or higher
- [ ] **Git** installed and configured
- [ ] **Claude Code CLI** installed (for AI-assisted development)
- [ ] **OpenRouter account** (free tier available - https://openrouter.ai/)

---

## Phase 1: Environment Setup (15 min)

### 1.1 Clone Repository

```bash
git clone <repository-url>
cd NativeLocal_SLM_App
```

- [ ] Repository cloned successfully
- [ ] `cd` into project directory

### 1.2 Open in Android Studio

- [ ] Open Android Studio
- [ ] Select "Open an Existing Project"
- [ ] Navigate to `NativeLocal_SLM_App` directory
- [ ] Wait for Gradle sync to complete

**Troubleshooting**: If Gradle sync fails:
- Check internet connection
- Verify JDK 11+ is configured in Android Studio
- Try File → Invalidate Caches → Restart

### 1.3 Configure JAVA_HOME

```bash
# Windows
setx JAVA_HOME "C:\Program Files\Android\Android Studio\jbr"

# Verify
echo %JAVA_HOME%
```

- [ ] JAVA_HOME set
- [ ] Verify with `java -version`

---

## Phase 2: Claude Memory Setup (10 min)

### 2.1 Install claude-mem Plugin

```bash
claude plugin marketplace add thedotmack/claude-mem
claude plugin install claude-mem
```

- [ ] Plugin installed successfully
- [ ] Restarted Claude Code

### 2.2 Get OpenRouter API Key

1. Go to https://openrouter.ai/
2. Sign up (GitHub, Google, or email)
3. Navigate to API Keys section
4. Create new API key
5. Copy the key (starts with `sk-or-v1-`)

- [ ] OpenRouter account created
- [ ] API key obtained

### 2.3 Configure API Key

**Option A: Environment Variable (Recommended)**

```powershell
# Windows PowerShell
[System.Environment]::SetEnvironmentVariable('OPENROUTER_API_KEY', 'your-api-key', 'User')
```

- [ ] API key configured
- [ ] Verified with: `powershell -Command "Write-Output $env:OPENROUTER_API_KEY"`

### 2.4 Verify Installation

```bash
# Check worker service
curl http://localhost:37777/health

# Expected: {"status":"ok","timestamp":...}
```

- [ ] Worker service running
- [ ] Health check returns "ok"

**See**: [docs/CLAUDE_MEMORY_SETUP.md](CLAUDE_MEMORY_SETUP.md) for detailed guide

---

## Phase 3: Project Assets Setup (10 min)

### 3.1 Download MediaPipe Models

**Required for app functionality**:

1. **Hair Segmenter Model**:
   - Go to: https://developers.google.com/mediapipe/solutions/vision/image_segmenter
   - Download `hair_segmenter.tflite`
   - Place in: `app/src/main/assets/`

2. **Face Landmarker Model**:
   - Go to: https://developers.google.com/mediapipe/solutions/vision/face_landmarker
   - Download `face_landmarker.tflite`
   - Place in: `app/src/main/assets/`

- [ ] `hair_segmenter.tflite` in `app/src/main/assets/`
- [ ] `face_landmarker.tflite` in `app/src/main/assets/`

**Note**: Without these models, the app will crash on startup.

### 3.2 Add Filter Assets (Optional)

For full filter functionality, add PNG assets:

```bash
# Create directory structure
mkdir -p app/src/main/assets/filters/face
mkdir -p app/src/main/assets/filters/hair
mkdir -p app/src/main/assets/filters/combo
```

**Example filter structure**:
```
filters/face/batman/
├── mask.png
├── eyes.png
└── metadata.json
```

- [ ] Filter assets added (optional)
- [ ] Tested filter functionality

---

## Phase 4: Build & Run (10 min)

### 4.1 Build Debug APK

```bash
# From project root
gradlew.bat assembleDebug
```

- [ ] Build completed without errors
- [ ] APK generated: `app/build/outputs/apk/debug/app-debug.apk`

### 4.2 Install on Device

**Option A: Via Gradle**

```bash
gradlew.bat installDebug
```

**Option B: Via ADB**

```bash
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

- [ ] App installed on device/emulator
- [ ] App icon appears in launcher

### 4.3 Run Application

- [ ] Launch app from device or Android Studio
- [ ] Complete onboarding flow
- [ ] Grant camera permissions when prompted
- [ ] Verify camera preview appears
- [ ] Test basic functionality (apply a filter)

---

## Phase 5: Testing & Verification (5 min)

### 5.1 Run Unit Tests

```bash
gradlew.bat test
```

- [ ] All unit tests pass
- [ ] Test report generated: `app/build/reports/tests/test/index.html`

### 5.2 Check Code Coverage

```bash
gradlew.bat test jacocoTestReport
```

- [ ] JaCoCo report generated
- [ ] Coverage report: `app/build/reports/jacoco/test/html/index.html`
- [ ] **Target**: 100% code coverage (see Pass Condition 1)

### 5.3 Run E2E Tests (Manual)

See [E2E_TEST_SCENARIOS.md](../E2E_TEST_SCENARIOS.md)

**Quick smoke test**:
- [ ] **Scenario 1**: Onboarding → Camera → Filter → Capture → Save
- [ ] **Scenario 2**: Color selection → Real-time preview → Save
- [ ] **Scenario 3**: Before/After slider functionality

---

## Phase 6: Documentation Review (5 min)

### Required Reading

- [ ] [README.md](../README.md) - Project overview and quick start
- [ ] [CLAUDE.md](../CLAUDE.md) - Project instructions for AI assistants
- [ ] [docs/CLAUDE_MEMORY_SETUP.md](CLAUDE_MEMORY_SETUP.md) - Memory system setup
- [ ] [E2E_TEST_SCENARIOS.md](../E2E_TEST_SCENARIOS.md) - Testing guide
- [ ] [IMPLEMENTATION_SUMMARY.md](../IMPLEMENTATION_SUMMARY.md) - Architecture details

### Project Context Files

- [ ] `.claude/PROJECT_CONTEXT.md` - Project-specific context for memory
- [ ] `.claude/TOKEN_OPTIMIZATION.md` - Memory optimization guide
- [ ] `.claude/MEMORY_SETUP_PLAN.md` - Memory configuration plan

---

## Verification Checklist

### Environment ✅

- [ ] Android Studio opens project without errors
- [ ] Gradle sync completes successfully
- [ ] JAVA_HOME configured correctly
- [ ] Device/emulator connected and detected

### Dependencies ✅

- [ ] MediaPipe models downloaded and in place
- [ ] Filter assets added (optional but recommended)
- [ ] All dependencies resolved (check build.gradle.kts)

### Build ✅

- [ ] Debug APK builds successfully
- [ ] No compilation errors
- [ ] No lint errors (check `gradlew.bat lint`)

### Runtime ✅

- [ ] App launches without crashes
- [ ] Camera permission handled correctly
- [ ] Camera preview displays (25-30 FPS)
- [ ] Filters apply successfully

### Testing ✅

- [ ] Unit tests pass
- [ ] Code coverage measured (target: 100%)
- [ ] E2E smoke tests pass

### Memory System ✅

- [ ] claude-mem plugin installed
- [ ] OpenRouter API configured
- [ ] Worker service running
- [ ] Web viewer accessible (http://localhost:37777)

---

## Troubleshooting

### Common Issues

**Issue**: Gradle sync fails
- **Solution**: Check internet, verify JDK, invalidate caches

**Issue**: App crashes on startup
- **Solution**: Verify MediaPipe models are in `app/src/main/assets/`

**Issue**: Camera preview black
- **Solution**: Check camera permissions, verify device has camera

**Issue**: Filters not applying
- **Solution**: Verify filter assets exist, check metadata.json format

**Issue**: Memory system not working
- **Solution**: Check API key, verify worker service, see setup guide

### Getting Help

- **Claude Memory Issues**: [docs/CLAUDE_MEMORY_SETUP.md](CLAUDE_MEMORY_SETUP.md)
- **Build Issues**: [IMPLEMENTATION_SUMMARY.md](../IMPLEMENTATION_SUMMARY.md)
- **Testing Issues**: [E2E_TEST_SCENARIOS.md](../E2E_TEST_SCENARIOS.md)
- **General Issues**: Check [README.md](../README.md) or contact team

---

## Next Steps

After completing onboarding:

1. **Explore the codebase**: Start with `MainActivity.kt` and follow the architecture
2. **Review architecture**: Read [IMPLEMENTATION_SUMMARY.md](../IMPLEMENTATION_SUMMARY.md)
3. **Make a test change**: Add a log statement, build, and verify
4. **Run E2E tests**: Complete all 5 scenarios in [E2E_TEST_SCENARIOS.md](../E2E_TEST_SCENARIOS.md)
5. **Contribute**: Check for open issues or create your first PR

---

## Quick Reference Commands

```bash
# Build
gradlew.bat assembleDebug
gradlew.bat assembleRelease

# Test
gradlew.bat test
gradlew.bat test jacocoTestReport
gradlew.bat connectedAndroidTest

# Install
gradlew.bat installDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk

# Debug
adb logcat -c && adb logcat | grep "NativeLocal_SLM_App"
adb shell dumpsys gfxinfo com.example.nativelocal_slm_app

# Memory
curl http://localhost:37777/health
start http://localhost:37777
```

---

**Onboarding Status**: Complete all checkboxes above
**Estimated Time**: 30-45 minutes
**Questions**: Refer to documentation or contact team
