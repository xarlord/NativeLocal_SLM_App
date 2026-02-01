# Step-by-Step Guide: Install API 33 Emulator for UI Testing

Follow these steps in Android Studio to set up an API 33 emulator and run the UI tests.

---

## Step 1: Install SDK Command-Line Tools

1. Open **Android Studio**
2. Go to **Tools → SDK Manager**
3. Click on the **SDK Tools** tab
4. Check the box next to **Android SDK Command-line Tools (latest)**
5. Click **Apply** to download and install
6. Accept the license agreements
7. Wait for installation to complete

---

## Step 2: Download API 33 System Image

1. Still in **SDK Manager**, click on the **SDK Platforms** tab
2. Check the box next to **Android 13.0 (API 33)**
3. On the right side, check:
   - ✅ **Android SDK Platform 33**
   - ✅ **Google APIs Intel x86_64 Atom System Image** (recommended)
   - OR: **Google Play Intel x86_64 Atom System Image** (includes Play Store)
4. Click **Apply** to download
5. Accept license agreements
6. Wait for download (approximately 1-2 GB)

**Alternative: If you prefer API 34**
- Download **Android 14.0 (API 34)** instead
- Both API 33 and 34 work well with Compose UI tests

---

## Step 3: Create New AVD (Virtual Device)

### Option A: Using Android Studio GUI (Easier)

1. In Android Studio, go to **Tools → AVD Manager**
2. Click **Create Virtual Device**
3. Select a phone (e.g., **Pixel 6** or **Medium Phone**)
4. Click **Next**
5. Under **System Image**, select **API 33** (the one you just downloaded)
6. If API 33 doesn't appear, click **Download** next to it
7. Click **Next** → **Finish**

### Option B: Using Command Line

Once command-line tools are installed, open a terminal in the project:

```bash
# Set JAVA_HOME
set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr
set PATH=%JAVA_HOME%\bin;%PATH%

# Create AVD
cd C:\Users\plner\AppData\Local\Android\Sdk\tools\bin
avdmanager create avd -n "Medium_Phone_API_33" -k "system-images;android-33;google_apis;x86_64" -d "medium" -f

# Launch emulator
cd C:\Users\plner\AppData\Local\Android\Sdk\emulator
emulator -avd Medium_Phone_API_33
```

---

## Step 4: Launch the New Emulator

1. Go to **Tools → AVD Manager**
2. Find your new **API 33** emulator
3. Click the **Play** button to launch it
4. Wait for the emulator to fully boot up (you'll see the home screen)

---

## Step 5: Run UI Tests

Once the API 33 emulator is running, execute these commands:

```bash
# Navigate to project directory
cd C:\Users\plner\AndroidStudioProjects\NativeLocal_SLM_App

# Set JAVA_HOME
set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr

# Run instrumented UI tests
gradlew.bat :app:connectedDebugAndroidTest
```

Or create this batch file and run it:

**run_ui_tests_api33.bat:**
```batch
@echo off
set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr
set PATH=%JAVA_HOME%\bin;%PATH%
cd /d "C:\Users\plner\AndroidStudioProjects\NativeLocal_SLM_App"

echo Checking for connected devices...
"C:\Users\plner\AppData\Local\Android\Sdk\platform-tools\adb.exe" devices

echo.
echo Running instrumented UI tests on API 33 emulator...
call gradlew.bat :app:connectedDebugAndroidTest
```

---

## Step 6: Generate Coverage Report

After tests pass, generate the coverage report:

```bash
gradlew.bat jacocoAndroidTestReport
```

This will generate a combined coverage report in:
`app/build/reports/jacoco/jacocoAndroidTestReport/html/index.html`

---

## Expected Results

### Test Results
- **22 Compose UI tests** should pass
- Total tests: **276** (254 existing + 22 new UI tests)
- 100% pass rate

### Coverage Improvement
- **Current**: 1.73% (368/21,280 instructions)
- **Expected after UI tests**: 60-70% coverage
- **Additional coverage**: ~13,000 instructions

### Coverage Breakdown After UI Tests
| Package | Current | After UI Tests |
|--------|---------|----------------|
| data.model | 57% | 57% ✅ |
| ui.components | 0% | ~70% 📈 |
| presentation.filters | 0% | ~65% 📈 |
| presentation.onboarding | 0% | ~85% 📈 |
| ui.theme | 0% | ~50% 📈 |

---

## Troubleshooting

### Issue: "System image not found"
**Solution**: Make sure you completed Step 2 and the download finished successfully

### Issue: "Emulator is too slow"
**Solution**:
- Enable hardware acceleration (HAXM or Hyper-V)
- Reduce RAM in AVD settings (try 1024 MB instead of 2048 MB)
- Use x86_64 image (not ARM)

### Issue: "Tests still fail with Espresso error"
**Solution**: Verify you're running API 33 or 34, not 36:
```bash
adb shell getprop ro.build.version.sdk
# Should output: 33 or 34
```

### Issue: "Emulator won't boot"
**Solution**:
- Cold boot: AVD Manager → Dropdown next to Play button → **Cold Boot Now**
- Wipe data: AVD Manager → Dropdown → **Wipe Data**
- Recreate AVD

---

## Verification Commands

```bash
# Check connected devices
adb devices

# Check Android API level
adb shell getprop ro.build.version.sdk

# Check emulator is running
adb shell getprop ro.product.model

# Run only UI tests
gradlew.bat :app:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=com.example.nativelocal_slm_app.ComposeInstrumentedTest
```

---

## Quick Summary

1. ✅ Install SDK Command-line Tools
2. ✅ Download API 33 System Image
3. ✅ Create API 33 AVD
4. ✅ Launch API 33 Emulator
5. ✅ Run: `gradlew.bat :app:connectedDebugAndroidTest`
6. ✅ Coverage increases to 60-70%

---

## Contact

If you encounter any issues:
1. Check the Android Studio logs
2. Run with `--stacktrace` flag: `gradlew.bat :app:connectedDebugAndroidTest --stacktrace`
3. Review test report: `app/build/reports/androidTests/connected/debug/index.html`
