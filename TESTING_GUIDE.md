# 🧪 Testing Guide for NativeLocal_SLM_App

## 📱 Prerequisites

✅ **Emulator Already Running**: `emulator-5554` (Pixel 6 API 33)
✅ **All Refactoring Complete**: Phases 1-4 merged to master

---

## 🚀 Option 1: Build & Run via Android Studio (RECOMMENDED)

### **Step 1: Open Project in Android Studio**

1. **Launch Android Studio**
2. **Open project**: `C:\Users\plner\AndroidStudioProjects\NativeLocal_SLM_App`
3. **Wait for Gradle sync to complete** (check bottom-right progress bar)

### **Step 2: Build and Run App**

1. **Select configuration**: "app" (dropdown next to Run button)
2. **Select device**: Pixel_6_API_33 (emulator-5554)
3. **Click Run button** (▶️ green play icon) OR press `Shift+F10`

**Expected**: App launches on emulator → Onboarding screen appears

### **Step 3: Run Instrumented Tests**

#### **Option A: Run All Tests**
1. Right-click on `app` module in Project panel
2. Select: **"Run 'app' connectedAndroidTest"**
3. Tests will run on emulator (takes 5-10 minutes)

#### **Option B: Run Specific Test Class**
1. Navigate to: `app/src/androidTest/java/com/example/nativelocal_slm_app/`
2. Right-click on test class (e.g., `MainActivityTest.kt`)
3. Select: **"Run 'MainActivityTest'"**

---

## 🎯 E2E Test Scenarios (Manual Testing)

### **Test 1: Onboarding Flow**
**Priority**: CRITICAL
**Steps**:
1. Launch app
2. View onboarding pages (swipe through or tap "Next")
3. Tap "Get Started" or "Done"

**Expected**: Navigate to camera screen

---

### **Test 2: Camera Screen**
**Priority**: CRITICAL
**Steps**:
1. Verify camera preview displays (should show live camera feed)
2. Check frame rate is smooth (25-30 FPS)
3. Look for filter carousel at bottom
4. Tap filter icon to open filter sheet
5. Select a filter (e.g., "Batman", "Joker")

**Expected**:
- Camera preview renders at 25-30 FPS
- Filter carousel visible
- Filters apply in real-time
- No crashes or ANRs

---

### **Test 3: Capture Photo**
**Priority**: CRITICAL
**Steps**:
1. Apply a filter on camera screen
2. Tap capture button (camera icon)
3. View results screen with before/after comparison

**Expected**:
- Photo captured successfully
- Results screen shows original vs filtered
- Save and Share buttons visible
- Comparison slider works

---

### **Test 4: Filter Selection**
**Priority**: HIGH
**Steps**:
1. On camera screen, tap any filter icon
2. Filter selection sheet opens
3. Browse different filter categories (Face, Hair, Combo)
4. Select various filters
5. Verify real-time preview

**Expected**:
- Sheet opens smoothly
- Category tabs work
- Filters apply instantly
- No visible lag

---

### **Test 5: Before/After Slider**
**Priority**: HIGH
**Steps**:
1. Capture a photo
2. On results screen, use the comparison slider
3. Drag slider left/right
4. Verify before/after comparison

**Expected**:
- Slider moves smoothly
- Before image visible on left
- After image visible on right
- Images transition seamlessly

---

### **Test 6: Performance Under Load**
**Priority**: MEDIUM
**Steps**:
1. Open camera screen
2. Rapidly switch between 10+ different filters
3. Capture 3-5 photos in quick succession
4. Navigate to results screen each time

**Expected**:
- No crashes
- No out-of-memory errors
- Frame rate stays above 20 FPS
- App remains responsive

---

## 📊 Automated Test Results

### **Run All Instrumented Tests**

**Via Command Line** (from project root):
```batch
cd C:\Users\plner\AndroidStudioProjects\NativeLocal_SLM_App
gradlew.bat connectedAndroidTest
```

**Test Coverage**:
- **Total Tests**: ~161 instrumented tests
- **Categories**:
  - UI Component Tests (50+)
  - Integration Tests (30+)
  - Camera Tests (20+)
  - Filter Tests (40+)
  - Onboarding Tests (15+)
  - E2E Tests (6+)

---

## 🔍 Test Checklist

### **Critical Path Tests** (Must Pass)
- [ ] App launches without crash
- [ ] Camera permission requested and granted
- [ ] Camera preview displays at 25-30 FPS
- [ ] Filters apply in real-time
- [ ] Photo capture works
- [ ] Results screen displays correctly
- [ ] Before/After slider functions
- [ ] Save photo works

### **UI Tests** (Important)
- [ ] All filter icons display correctly
- [ ] Filter sheet opens/closes smoothly
- [ ] Category tabs work
- [ ] Color picker functions (if accessible)
- [ ] Bottom sheets render correctly
- [ ] Navigation works (back buttons, etc.)

### **Performance Tests** (Nice to Have)
- [ ] Frame rate > 25 FPS during filter application
- [ ] Memory usage < 300MB
- [ ] No ANR (Application Not Responding) dialogs
- [ ] Smooth animations (60fps UI, 30fps camera)

---

## 🐛 Known Issues

### **Windows File Lock**
**Problem**: Build directory locked by Android Studio or Gradle daemon

**Solution**:
1. Close Android Studio completely
2. Run: `gradlew.bat --stop`
3. Check Task Manager for `java.exe` or `gradle.exe` processes
4. End those processes if found
5. Retry build

### **MediaPipe Models Missing**
**Problem**: ML models not in assets folder

**Expected Behavior**: Graceful fallback with error message

**To Fix**:
1. Download models from: `mediapipe.google.com`
2. Place in: `app/src/main/assets/`
3. Filename: `hair_segmenter.tflite`, `face_landmarker.tflite`

---

## 📈 Success Criteria

### **All Tests Pass When**:
✅ No crashes during normal usage
✅ Camera runs at 25-30 FPS
✅ Filters apply smoothly
✅ Photo capture/save works
✅ Before/After comparison works
✅ Memory stays under 300MB
✅ No ANR dialogs

### **Test Results Location**:
- **HTML Report**: `app\build\reports\androidTests\connected\index.html`
- **Coverage Report**: `app\build\reports\coverage\index.html`
- **XML Results**: `app\build\test-results\connectedAndroidTest\`

---

## 🎯 Quick Test Command (Once File Lock Resolved)

```batch
# Build, install, and test all in one command
gradlew.bat assembleDebug installDebug connectedAndroidTest
```

---

## 📝 Test Notes

**Emulator**: Pixel 6 API 33 (Android 13)
**Device ID**: emulator-5554
**Android Version**: 13 (API 33)
**Build Variant**: debug

**Testing Status**: Ready to test (file lock issue preventing automated build)

---

**Generated**: 2026-02-02
**Branch**: master
**Commit**: d24a83d (Phase 4 complete)
