# E2E Test Scenarios

This document describes the End-to-End (E2E) test scenarios that must be manually verified on a target device before the implementation is considered complete.

## Test Environment Setup

### Build and Install

```bash
# Build debug APK
./gradlew assembleDebug

# Install on connected device
adb install -r app/build/outputs/apk/debug/app-debug.apk

# Monitor logs
adb logcat -c && adb logcat | grep "NativeLocal_SLM_App"
```

### Performance Monitoring

```bash
# Check GPU performance
adb shell dumpsys gfxinfo com.example.nativelocal_slm_app

# Check memory usage
adb shell dumpsys meminfo com.example.nativelocal_slm_app
```

---

## E2E Test Scenarios

### Scenario 1: Happy Path - Basic Filter

**Objective**: Verify the basic user flow from app launch to saving a photo with a filter.

**Steps**:
1. Launch the app
2. Complete onboarding (swipe through all pages or tap "Skip")
3. Grant camera permission when prompted
4. Wait for hair detection to initialize (should see camera preview)
5. Tap "Select Filter" button
6. Select "Batman" filter from FACE category
7. Verify filter overlay appears on camera preview
8. Tap capture button (circular button at bottom)
9. Verify results screen shows before/after comparison
10. Drag slider to verify comparison works at different positions (0%, 50%, 100%)
11. Tap "Save" button
12. Verify success indication or navigate to history

**Expected Results**:
- Onboarding completes successfully
- Camera permission handled correctly
- Face and hair detection works in real-time
- Batman filter overlay renders correctly on face
- Before/after slider functions smoothly
- Photo saves to history

**Performance Requirements**:
- Camera preview: 25-30 FPS
- Filter application: < 100ms latency
- No crashes or ANRs

---

### Scenario 2: Color Change Workflow

**Objective**: Verify hair color extraction and application.

**Steps**:
1. Open camera
2. Wait for hair detection
3. Tap "Select Filter"
4. Navigate to color picker (if available) or select a color-based filter
5. Select red color
6. Verify real-time color change on hair region
7. Adjust intensity slider (if available)
8. Capture and save photo

**Expected Results**:
- Color picker displays predefined colors
- Hair color changes in real-time
- Intensity adjustment smooth
- Captured photo shows correct color application

---

### Scenario 3: Before-After Comparison

**Objective**: Verify before/after slider functionality at different positions.

**Steps**:
1. Capture a photo with filter applied
2. On results screen, test slider at:
   - 50% (center)
   - 0% (showing full "after" image)
   - 100% (showing full "before" image)
   - Various positions in between
3. Verify smooth transition and correct image display

**Expected Results**:
- Slider moves smoothly
- Images render correctly at all positions
- Divider line clearly visible
- No lag or stuttering during slider movement

---

### Scenario 4: Memory Pressure Test

**Objective**: Verify app handles rapid photo capture without memory issues.

**Steps**:
1. Open camera
2. Capture 10 photos rapidly (tap capture button quickly)
3. Verify no OutOfMemoryError occurs
4. Verify UI remains responsive
5. Check memory usage with `adb shell dumpsys meminfo`
6. Navigate to history
7. Verify all 10 photos are saved
8. Delete all photos one by one

**Expected Results**:
- No OOM crashes
- Memory usage < 300MB
- UI remains responsive during rapid capture
- All photos save successfully
- Photos can be deleted without issues

---

### Scenario 5: Camera Performance Test

**Objective**: Verify camera performance with complex filters.

**Steps**:
1. Open camera
2. Monitor FPS for 30 seconds without filter
3. Apply a complex filter (e.g., "Cyberpunk" combo filter)
4. Monitor FPS for another 30 seconds
5. Switch between multiple filters rapidly
6. Verify no significant FPS drop

**Expected Results**:
- No filter: 25-30 FPS
- With complex filter: No drop below 20 FPS
- Smooth transitions between filters
- No frame drops lasting > 1 second

**Performance Metrics**:
```
# Monitor FPS
adb shell dumpsys gfxinfo com.example.nativelocal_slm_app

# Check for frame drops
# Look for "Janky frames" percentage
# Should be < 10%
```

---

## Pass Condition Checklist

Both of the following must be met:

### ✅ Pass Condition 1: 100% Code Coverage

```bash
# Run unit tests with coverage
./gradlew test jacocoTestReport

# Verify coverage report shows 100%
# Report location: app/build/reports/jacoco/test/html/index.html
```

### ✅ Pass Condition 2: All E2E Tests Pass

All 5 E2E scenarios above must pass on target device with:
- No crashes
- No ANRs
- Performance within specified limits
- All features working as expected

---

## Debugging Tips

### Enable Verbose Logging

In debug build, MediaPipe logging is enabled. Monitor with:
```bash
adb logcat | grep -E "NativeLocal_SLM_App|MediaPipe|CameraX"
```

### Common Issues

1. **Camera not showing**: Verify permissions granted
2. **Filters not applying**: Check MediaPipe models are present in assets
3. **Crash on capture**: Check logcat for MediaPipe errors
4. **Poor FPS**: Check if device supports required GPU features

### Breakpoints for Debugging

Set breakpoints at:
- `CameraViewModel.kt:82` (frame received)
- `ProcessCameraFrameUseCase.kt:45` (before processing)
- `MediaPipeHairRepository.kt:67` (after segmentation)
- `ApplyFilterUseCase.kt:103` (during composition)
- `CameraScreen.kt:189` (UI state update)

---

## Test Completion

After all E2E tests pass:

1. Document any issues found
2. Fix issues and re-test
3. Update this document with final test results
4. Mark implementation as complete
