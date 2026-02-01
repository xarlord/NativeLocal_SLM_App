# Missing Requirements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement all missing critical functionality to meet Pass Condition 1 (100% code coverage) and Pass Condition 2 (all E2E tests pass)

**Architecture:** Continue with MVI + Clean Architecture, add real MediaPipe integration, proper CameraX setup, persistence layer, and comprehensive testing

**Tech Stack:** MediaPipe Tasks Vision, CameraX, Room/SharedPreferences, JaCoCo, JUnit4, Mockk, AndroidX Test

---

## Overview

This plan addresses 13 critical missing items identified through systematic analysis:

1. **Testing Infrastructure** - JaCoCo for 100% coverage enforcement
2. **MediaPipe Integration** - Real hair segmentation and face landmark detection
3. **Camera Implementation** - Actual CameraX preview and frame processing
4. **Filter Assets** - Create placeholder filter assets with metadata
5. **Permissions** - Runtime camera and storage permission handling
6. **Persistence** - Save photos and maintain history
7. **UI Features** - Before/After slider, photo history
8. **Performance** - FPS monitoring, memory tracking, frame optimization
9. **E2E Testing** - Documented test procedures with pass/fail criteria

Each task follows TDD: write failing test → implement minimal code → verify → commit.

---

## Task 1: Set up JaCoCo for 100% Code Coverage

**Why:** Project requires 100% code coverage but JaCoCo is not properly configured

**Files:**
- Modify: `app/build.gradle.kts`
- Modify: `build.gradle.kts` (root)
- Create: `app/src/jacoco/testDebugUnitTest.exec` (generated)

**Step 1: Add JaCoCo plugin to root build.gradle.kts**

```kotlin
// In build.gradle.kts (root)
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.compose) apply false
    id("jacoco-report-aggregation") version "0.8.11" apply false
}
```

**Step 2: Configure JaCoCo in app/build.gradle.kts**

Add after line 46:

```kotlin
// In app/build.gradle.kts, after testCoverage block
plugins {
    jacoco
}

tasks.withType<JacocoReport> {
    dependsOn(tasks.withType<Test>())

    reports {
        xml.required.set(true)
        html.required.set(true)
        csv.required.set(false)
    }
}

// Add Jacoco test report task
tasks.register<JacocoReport>("jacocoTestReport") {
    dependsOn("testDebugUnitTest")

    sourceDirectories.setFrom(files("${project.projectDir}/src/main/java"))
    classDirectories.setFrom(files("${project.buildDir}/tmp/kotlin-classes/debug"))
    executionData.setFrom(files("${project.buildDir}/jacoco/testDebugUnitTest.exec"))

    reports {
        xml.required.set(true)
        html.required.set(true)
    }
}

// Add coverage verification
tasks.register<JacocoCoverageVerification>("jacocoTestCoverageVerification") {
    dependsOn("jacocoTestReport")

    sourceDirectories.setFrom(files("${project.projectDir}/src/main/java"))
    classDirectories.setFrom(files("${project.buildDir}/tmp/kotlin-classes/debug"))
    executionData.setFrom(files("${project.buildDir}/jacoco/testDebugUnitTest.exec"))

    violationRules {
        rule {
            limit {
                minimum = "1.0".toBigDecimal() // 100% coverage required
            }
        }
    }
}

// Make build depend on coverage verification
tasks.named("check") {
    dependsOn("jacocoTestCoverageVerification")
}
```

**Step 3: Run test to verify configuration**

Run: `gradlew.bat jacocoTestReport`
Expected: BUILD SUCCESSFUL with report generated at `app/build/reports/jacoco/index.html`

**Step 4: Run coverage verification (should fail initially)**

Run: `gradlew.bat jacocoTestCoverageVerification`
Expected: BUILD FAILED with coverage violation (expected, since coverage is low)

**Step 5: Commit**

```bash
git add build.gradle.kts app/build.gradle.kts
git commit -m "feat: configure JaCoCo for 100% code coverage enforcement"
```

---

## Task 2: Add MediaPipe Model Files to Assets

**Why:** Real hair analysis requires trained ML models

**Files:**
- Create: `app/src/main/assets/hair_segmenter.tflite`
- Create: `app/src/main/assets/face_landmarker.tflite`

**Step 1: Download MediaPipe models**

Download from Google MediaPipe:
- Hair Segmenter: https://storage.googleapis.com/mediapipe-models/hair_segmenter/hair_segmenter.tflite
- Face Landmarker: https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker.tflite

**Step 2: Create assets directory structure**

Run: `mkdir -p app/src/main/assets`

**Step 3: Copy model files to assets**

Place downloaded .tflite files in `app/src/main/assets/`

**Step 4: Verify files are included in APK**

Run: `gradlew.bat assembleDebug`
Run: `unzip -l app/build/outputs/apk/debug/app-debug.apk | grep tflite`
Expected: Both .tflite files listed in APK

**Step 5: Commit**

```bash
git add app/src/main/assets/*.tflite
git commit -m "feat: add MediaPipe hair segmenter and face landmarker models"
```

**Note:** If model files are too large for git, use .gitignore and document download location in README.

---

## Task 3: Implement Real MediaPipe Integration

**Why:** Current implementation returns stub data

**Files:**
- Modify: `app/src/main/java/com/example/nativelocal_slm_app/data/repository/MediaPipeHairRepository.kt`
- Test: `app/src/test/com/example/nativelocal_slm_app/data/repository/MediaPipeHairRepositoryTest.kt`

**Step 1: Write failing test for real MediaPipe integration**

Create test file:

```kotlin
package com.example.nativelocal_slm_app.data.repository

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.Before
import org.junit.Test
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class MediaPipeHairRepositoryTest {

    private lateinit var repository: MediaPipeHairRepository
    private lateinit var context: Context

    @Before
    fun setup() {
        context = mockk(relaxed = true)
        repository = MediaPipeHairRepository(context)
    }

    @Test
    fun `analyzeHair returns valid segmentation mask`() = runTest {
        val testBitmap = Bitmap.createBitmap(256, 256, Bitmap.Config.ARGB_8888)

        val result = repository.analyzeHair(testBitmap)

        assertNotNull(result.segmentationMask)
        assertEquals(testBitmap.width, result.segmentationMask.width)
        assertEquals(testBitmap.height, result.segmentationMask.height)
    }

    @Test
    fun `segmentHair returns non-null mask`() = runTest {
        val testBitmap = Bitmap.createBitmap(256, 256, Bitmap.Config.ARGB_8888)

        val mask = repository.segmentHair(testBitmap)

        assertNotNull(mask)
        assertTrue(mask.width > 0)
        assertTrue(mask.height > 0)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `gradlew.bat test --tests MediaPipeHairRepositoryTest`
Expected: Tests fail because MediaPipe is not initialized

**Step 3: Implement real MediaPipe integration**

Replace content of `MediaPipeHairRepository.kt`:

```kotlin
package com.example.nativelocal_slm_app.data.repository

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facesegmenter.FaceSegmenter
import com.google.mediapipe.tasks.vision.facesegmenter.FaceSegmenterOptions
import com.google.mediapipe.tasks.vision.facedetector.FaceDetector
import com.google.mediapipe.tasks.vision.facedetector.FaceDetectorOptions
import com.example.nativelocal_slm_app.domain.model.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class MediaPipeHairRepository(context: Context) : HairAnalysisRepository {

    private var faceSegmenter: FaceSegmenter? = null
    private var faceDetector: FaceDetector? = null
    private val appContext = context.applicationContext

    init {
        initializeMediaPipe()
    }

    private fun initializeMediaPipe() {
        val baseOptions = BaseOptions.builder()
            .setModelAssetPath("hair_segmenter.tflite")
            .build()

        val segmenterOptions = FaceSegmenterOptions.builder()
            .setBaseOptions(baseOptions)
            .setRunningMode(RunningMode.IMAGE)
            .build()

        faceSegmenter = FaceSegmenter.createFromOptions(appContext, segmenterOptions)

        // Initialize face detector
        val faceBaseOptions = BaseOptions.builder()
            .setModelAssetPath("face_landmarker.tflite")
            .build()

        val faceDetectorOptions = FaceDetectorOptions.builder()
            .setBaseOptions(faceBaseOptions)
            .setRunningMode(RunningMode.IMAGE)
            .build()

        faceDetector = FaceDetector.createFromOptions(appContext, faceDetectorOptions)
    }

    override suspend fun analyzeHair(image: Bitmap): HairAnalysisResult = withContext(Dispatchers.Default) {
        val startTime = System.currentTimeMillis()

        // Segment hair
        val mask = segmentHairInternal(image)

        // Detect face landmarks
        val faceLandmarks = detectFaceLandmarksInternal(image)

        // Analyze hair properties (simplified for now)
        val hairAnalysis = HairAnalysis(
            hairType = HairType.STRAIGHT,
            hairLength = HairLength.MEDIUM,
            textureScore = 0.5f,
            volumeEstimate = 0.5f,
            confidence = 0.7f
        )

        val hairColor = extractHairColor(image, mask)

        val processingTime = System.currentTimeMillis() - startTime

        HairAnalysisResult(
            segmentationMask = mask,
            hairAnalysis = hairAnalysis,
            hairColor = hairColor,
            faceLandmarks = faceLandmarks,
            processingTimeMs = processingTime
        )
    }

    override suspend fun segmentHair(image: Bitmap): Bitmap? = withContext(Dispatchers.Default) {
        segmentHairInternal(image)
    }

    override suspend fun detectFaceLandmarks(image: Bitmap): FaceLandmarksResult? = withContext(Dispatchers.Default) {
        detectFaceLandmarksInternal(image)
    }

    private fun segmentHairInternal(image: Bitmap): Bitmap {
        val mpImage: MPImage = BitmapImageBuilder(image).build()
        val result = faceSegmenter?.segment(mpImage)

        // Create mask from segmentation result
        val mask = Bitmap.createBitmap(image.width, image.height, Bitmap.Config.ARGB_8888)

        result?.categoryMask?.let { categoryMask ->
            // Convert category mask to bitmap
            for (y in 0 until image.height) {
                for (x in 0 until image.width) {
                    val category = categoryMask.get()[y * image.width + x]
                    if (category == 1) { // Hair category
                        mask.setPixel(x, y, Color.WHITE)
                    } else {
                        mask.setPixel(x, y, Color.TRANSPARENT)
                    }
                }
            }
        }

        return mask
    }

    private fun detectFaceLandmarksInternal(image: Bitmap): FaceLandmarksResult? {
        val mpImage: MPImage = BitmapImageBuilder(image).build()
        val result = faceDetector?.detect(mpImage)

        if (result?.detections().isNullOrEmpty()) {
            return null
        }

        val detection = result!!.detections()!![0]
        val boundingBox = detection.boundingBox()

        return FaceLandmarksResult(
            boundingBox = BoundingBox(
                left = boundingBox.left(),
                top = boundingBox.top(),
                right = boundingBox.right(),
                bottom = boundingBox.bottom()
            ),
            keyPoints = emptyMap(), // Simplified - would extract actual landmarks
            confidence = detection.categories()[0].score()
        )
    }

    private fun extractHairColor(image: Bitmap, mask: Bitmap): ColorInfo {
        // Sample pixels in hair region
        var totalR = 0
        var totalG = 0
        var totalB = 0
        var count = 0

        for (y in 0 until image.height step 10) {
            for (x in 0 until image.width step 10) {
                if (mask.getPixel(x, y) == Color.WHITE) {
                    val pixel = image.getPixel(x, y)
                    totalR += Color.red(pixel)
                    totalG += Color.green(pixel)
                    totalB += Color.blue(pixel)
                    count++
                }
            }
        }

        if (count == 0) {
            return ColorInfo(
                primaryColor = androidx.compose.ui.graphics.Color.Black,
                brightness = 0.5f,
                saturation = 0.5f
            )
        }

        val avgR = totalR / count
        val avgG = totalG / count
        val avgB = totalB / count

        val brightness = (avgR + avgG + avgB) / (255f * 3)
        val max = maxOf(avgR, avgG, avgB).toFloat()
        val min = minOf(avgR, avgG, avgB).toFloat()
        val saturation = if (max == 0f) 0f else (max - min) / max

        return ColorInfo(
            primaryColor = androidx.compose.ui.graphics.Color(avgR / 255f, avgG / 255f, avgB / 255f),
            brightness = brightness,
            saturation = saturation
        )
    }

    override fun release() {
        faceSegmenter?.close()
        faceDetector?.close()
        faceSegmenter = null
        faceDetector = null
    }
}
```

**Step 4: Run test to verify it passes**

Run: `gradlew.bat test --tests MediaPipeHairRepositoryTest`
Expected: Tests pass

**Step 5: Commit**

```bash
git add app/src/main/java/com/example/nativelocal_slm_app/data/repository/MediaPipeHairRepository.kt
git add app/src/test/.../MediaPipeHairRepositoryTest.kt
git commit -m "feat: implement real MediaPipe hair segmentation and face landmark detection"
```

---

## Task 4: Create Filter Assets and Metadata

**Why:** Filter system requires PNG assets and metadata

**Files:**
- Create: `app/src/main/assets/filters/face/batman/mask.png`
- Create: `app/src/main/assets/filters/face/batman/eyes.png`
- Create: `app/src/main/assets/filters/face/batman/metadata.json`
- (repeat for other filters)

**Step 1: Create directory structure**

Run:
```bash
mkdir -p app/src/main/assets/filters/face/batman
mkdir -p app/src/main/assets/filters/face/joker
mkdir -p app/src/main/assets/filters/hair/punk_mohawk
mkdir -p app/src/main/assets/filters/combo/wonder_woman
```

**Step 2: Create placeholder PNG files**

For each filter, create simple colored 512x512 PNG placeholders:
- mask.png: Semi-transparent overlay
- eyes.png: Eye effect
- (Can use ImageMagick or any image editor)

**Step 3: Create metadata.json files**

Example `batman/metadata.json`:

```json
{
  "id": "batman",
  "name": "Batman",
  "category": "face",
  "description": "Dark Knight mask",
  "assets": {
    "mask": "mask.png",
    "eyes": "eyes.png"
  },
  "blend_mode": "normal",
  "opacity": 0.8
}
```

**Step 4: Verify assets are included**

Run: `gradlew.bat assembleDebug`
Run: `unzip -l app/build/outputs/apk/debug/app-debug.apk | grep filters`
Expected: Filter assets listed

**Step 5: Commit**

```bash
git add app/src/main/assets/filters/
git commit -m "feat: add filter assets and metadata"
```

---

## Task 5: Implement CameraX Preview and ImageAnalysis

**Why:** Camera is currently placeholder

**Files:**
- Modify: `app/src/main/java/com/example/nativelocal_slm_app/presentation/camera/CameraPreview.kt`
- Test: `app/src/androidTest/.../CameraPreviewTest.kt`

**Step 1: Write failing test**

```kotlin
@Test
fun cameraPreview_rendersPreviewView() {
    composeTestRule.setContent {
        CameraPreview(viewModel = mockViewModel())
    }
    // Verify PreviewView is displayed
}
```

**Step 2: Implement CameraX preview**

Replace `CameraPreview.kt` with full CameraX implementation (using @androidx.camera.preview.PreviewView)

**Step 3: Run tests and verify**

**Step 4: Commit**

---

## Task 6: Add Storage Permissions and Handling

**Files:**
- Modify: `app/src/main/AndroidManifest.xml`
- Create: `app/src/main/java/com/example/nativelocal_slm_app/presentation/permissions/PermissionManager.kt`

**Step 1-5:** Add CAMERA and WRITE_EXTERNAL_STORAGE permissions, implement request handling with Accompanist

---

## Task 7: Implement Photo Save Functionality

**Files:**
- Modify: `app/src/main/java/com/example/nativelocal_slm_app/domain/usecase/SaveLookUseCase.kt`
- Test: `app/src/test/.../SaveLookUseCaseTest.kt`

**Step 1-5:** Implement real photo saving to app-specific storage or MediaStore

---

## Task 8: Add Comprehensive Unit Tests (100% Coverage)

**Files:**
- Create: Multiple test files for ViewModels, Use Cases, Repositories

**Step 1-5:** Write tests for each uncovered class until JaCoCo reports 100%

---

## Task 9: Add Instrumented Tests for Camera Integration

**Files:**
- Modify: `app/src/androidTest/.../CameraIntegrationTest.kt`
- Modify: `app/src/androidTest/.../MediaPipeIntegrationTest.kt`

**Step 1-5:** Implement real UI tests with camera and MediaPipe

---

## Task 10: Implement Before-After Comparison Slider

**Files:**
- Modify: `app/src/main/java/com/example/nativelocal_slm_app/presentation/results/BeforeAfterSlider.kt`

**Step 1-5:** Add slider logic with drag gesture and image clipping

---

## Task 11: Implement Photo History Persistence

**Files:**
- Create: `app/src/main/java/com/example/nativelocal_slm_app/data/local/SavedLookDatabase.kt`
- Create: `app/src/main/java/com/example/nativelocal_slm_app/data/local/SavedLookDao.kt`

**Step 1-5:** Add Room database or SharedPreferences for saved looks

---

## Task 12: Add Performance Monitoring and Optimization

**Files:**
- Create: `app/src/main/java/com/example/nativelocal_slm_app/utils/PerformanceMonitor.kt`
- Modify: `app/src/main/java/com/example/nativelocal_slm_app/presentation/camera/CameraViewModel.kt`

**Step 1-5:** Add FPS counter, frame skipping for 15fps UI processing

---

## Task 13: Create E2E Test Procedures Documentation

**Files:**
- Create: `docs/testing/e2e-test-procedures.md`

**Step 1: Document 5 E2E scenarios**

```markdown
# E2E Test Procedures

## Test 1: Happy Path - Basic Filter
**Steps:**
1. Launch app
2. Complete onboarding
3. Grant camera permissions
4. Select "Batman" filter
5. Tap capture button
6. Verify photo saved
7. Check Results screen

**Pass Criteria:**
- Camera preview displays (25-30 FPS)
- Filter overlay visible
- Photo captured successfully
- Result screen shows processed image
- Photo appears in history

**Fail Criteria:**
- App crashes
- Camera preview frozen
- Filter not applied
- Photo not saved

**Resolution:** If fails, check logs for CameraX or MediaPipe errors
```

(Repeat for all 5 scenarios)

**Step 2-5:** Document remaining scenarios, commit

---

## Execution Summary

This plan implements all 13 missing requirements systematically. Each task:
- Follows TDD (test first, then implement)
- Has clear verification steps
- Includes pass/fail criteria
- Creates git commits for review

**Total estimated tasks:** 65 individual steps (13 tasks × 5 steps each)

**QA for each task:**
- Pass: Test passes, builds successfully, coverage increases
- Fail: If test fails after 3 implementation attempts, ask user for direction

**Next step:** Choose execution approach:
1. Subagent-Driven (this session) - Use superpowers:subagent-driven-development
2. Parallel Session (separate) - Use superpowers:executing-plans

Which approach would you like?
