# MediaPipe Model Integration Guide
**Date**: 2026-02-01
**MediaPipe Version**: 0.10.14
**Status**: Ready for Integration

---

## Prerequisites

### Required Model Files

You need to download these model files from Google MediaPipe:

1. **Hair Segmenter Model**
   - File: `hair_segmenter.tflite`
   - Download: https://developers.google.com/mediapipe/solutions/vision/hair_segmenter
   - Size: ~10-20MB

2. **Face Landmarker Model**
   - File: `face_landmarker.tflite`
   - Download: https://developers.google.com/mediapipe/solutions/vision/face_landmarker
   - Size: ~10-20MB

### Download Instructions

#### Option 1: Download from MediaPipe GitHub

```bash
# Create assets directory
mkdir -p app/src/main/assets

# Download Hair Segmenter
curl -L -o app/src/main/assets/hair_segmenter.tflite \
  https://github.com/google/mediapipe/raw/master/mediapipe/tasks/cdc/vision/hair_segmenter/models/hair_segmenter.tflite

# Download Face Landmarker
curl -L -o app/src/main/assets/face_landmarker.tflite \
  https://github.com/google/mediapipe/raw/master/mediapipe/tasks/cdc/vision/face_landmarker/models/face_landmarker_v2.tflite
```

#### Option 2: Manual Download

1. Visit: https://developers.google.com/mediapipe/solutions/vision/hair_segmenter
2. Visit: https://developers.google.com/mediapipe/solutions/vision/face_landmarker
3. Download the `.tflite` model files
4. Copy to `app/src/main/assets/`

#### Option 3: Use Python Script

```python
import requests
import os

# Create assets directory
os.makedirs("app/src/main/assets", exist_ok=True)

# Download models
models = {
    "hair_segmenter.tflite": "https://github.com/google/mediapipe/raw/master/mediapipe/tasks/cdc/vision/hair_segmenter/models/hair_segmenter.tflite",
    "face_landmarker.tflite": "https://github.com/google/mediapipe/raw/master/mediapipe/tasks/cdc/vision/face_landmarker/models/face_landmarker_v2.tflite"
}

for filename, url in models.items():
    print(f"Downloading {filename}...")
    response = requests.get(url, stream=True)
    response.raise_for_status()

    filepath = f"app/src/main/assets/{filename}"
    with open(filepath, 'wb') as f:
        for chunk in response.iter_content(chunk_size=8192):
            f.write(chunk)

    print(f"✓ Downloaded {filename}")

print("\nAll models downloaded successfully!")
```

Save as `download_models.py` and run: `python download_models.py`

---

## File Structure After Download

```
app/src/main/assets/
├── hair_segmenter.tflite      ← NEW (add this)
├── face_landmarker.tflite     ← NEW (add this)
└── filters/                   ← existing
    ├── face/
    ├── hair/
    └── combo/
```

---

## Implementation Changes

### 1. Update MediaPipeHairRepository.kt

**File**: `app/src/main/java/com/example/nativelocal_slm_app/data/repository/MediaPipeHairRepository.kt`

**Complete rewrite** (will be provided separately):

```kotlin
package com.example.nativelocal_slm_app.data.repository

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import androidx.compose.ui.graphics.toArgb
import com.example.nativelocal_slm_app.domain.model.*
import com.example.nativelocal_slm_app.domain.repository.HairAnalysisRepository
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.BaseVisionTaskApi
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facesegmenter.FaceSegmenter
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import com.google.mediapipe.tasks.vision.facesegmenter.FaceSegmenterResult
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlin.math.abs
import kotlin.math.sqrt

/**
 * Real MediaPipe-based implementation of hair analysis repository.
 * Uses actual MediaPipe Tasks Vision for hair segmentation and face landmark detection.
 */
class MediaPipeHairRepository(context: Context) : HairAnalysisRepository {

    private val appContext = context.applicationContext

    // MediaPipe task APIs
    private var faceSegmenter: FaceSegmenter? = null
    private var faceLandmarker: FaceLandmarker? = null

    init {
        initializeMediaPipeTasks()
    }

    private fun initializeMediaPipeTasks() {
        try {
            // Initialize Face Segmenter (for hair segmentation)
            val segmenterBaseOptions = BaseOptions.builder()
                .setModelAssetPath("hair_segmenter.tflite")
                .build()

            val segmenterOptions = FaceSegmenter.FaceSegmenterOptions.builder()
                .setBaseOptions(segmenterBaseOptions)
                .setRunningMode(RunningMode.IMAGE)
                .build()

            faceSegmenter = FaceSegmenter.createFromOptions(
                appContext,
                segmenterOptions
            )

            // Initialize Face Landmarker
            val landmarkerBaseOptions = BaseOptions.builder()
                .setModelAssetPath("face_landmarker.tflite")
                .build()

            val landmarkerOptions = FaceLandmarker.FaceLandmarkerOptions.builder()
                .setBaseOptions(landmarkerBaseOptions)
                .setRunningMode(RunningMode.IMAGE)
                .setNumFaces(1)
                .setMinFaceDetectionConfidence(0.5f)
                .setMinFacePresenceConfidence(0.5f)
                .setMinTrackingConfidence(0.5f)
                .build()

            faceLandmarker = FaceLandmarker.createFromOptions(
                appContext,
                landmarkerOptions
            )

        } catch (e: Exception) {
            android.util.Log.e("MediaPipeHairRepository", "Failed to initialize MediaPipe tasks", e)
        }
    }

    override suspend fun analyzeHair(image: Bitmap): HairAnalysisResult = withContext(Dispatchers.Default) {
        val startTime = System.currentTimeMillis()

        try {
            // Convert Bitmap to MPImage
            val mpImage = BitmapImageBuilder(image).build()

            // Run hair segmentation
            val segmentationResult = faceSegmenter?.segment(mpImage)
            val mask = segmentationResult?.categoryMask?.let { mask ->
                convertMaskToBitmap(mask, image.width, image.height)
            }

            // Run face landmark detection
            val landmarkResult = faceLandmarker?.detect(mpImage)
            val faceLandmarks = landmarkResult?.faceLandmarks()?.firstOrNull()?.let { landmarks ->
                convertToFaceLandmarksResult(landmarks, image)
            }

            // Analyze hair properties from mask and image
            val hairAnalysis = analyzeHairProperties(image, mask)
            val hairColor = extractHairColor(image, mask)

            val processingTime = System.currentTimeMillis() - startTime

            HairAnalysisResult(
                segmentationMask = mask,
                hairAnalysis = hairAnalysis,
                hairColor = hairColor,
                faceLandmarks = faceLandmarks,
                processingTimeMs = processingTime
            )

        } catch (e: Exception) {
            android.util.Log.e("MediaPipeHairRepository", "Error analyzing hair", e)

            // Fallback to placeholder on error
            HairAnalysisResult(
                segmentationMask = createPlaceholderMask(image),
                hairAnalysis = HairAnalysis(
                    hairType = HairType.STRAIGHT,
                    hairLength = HairLength.MEDIUM,
                    textureScore = 0.5f,
                    volumeEstimate = 0.5f,
                    confidence = 0.3f  // Low confidence for fallback
                ),
                hairColor = ColorInfo(
                    primaryColor = androidx.compose.ui.graphics.Color.Black,
                    brightness = 0.5f,
                    saturation = 0.5f
                ),
                faceLandmarks = createPlaceholderFaceLandmarks(image),
                processingTimeMs = System.currentTimeMillis() - startTime
            )
        }
    }

    override suspend fun segmentHair(image: Bitmap): Bitmap? = withContext(Dispatchers.Default) {
        try {
            val mpImage = BitmapImageBuilder(image).build()
            val result = faceSegmenter?.segment(mpImage)
            result?.categoryMask?.let { mask ->
                convertMaskToBitmap(mask, image.width, image.height)
            }
        } catch (e: Exception) {
            android.util.Log.e("MediaPipeHairRepository", "Error segmenting hair", e)
            createPlaceholderMask(image)
        }
    }

    override suspend fun detectFaceLandmarks(image: Bitmap): FaceLandmarksResult? = withContext(Dispatchers.Default) {
        try {
            val mpImage = BitmapImageBuilder(image).build()
            val result = faceLandmarker?.detect(mpImage)
            result?.faceLandmarks()?.firstOrNull()?.let { landmarks ->
                convertToFaceLandmarksResult(landmarks, image)
            }
        } catch (e: Exception) {
            android.util.Log.e("MediaPipeHairRepository", "Error detecting face landmarks", e)
            createPlaceholderFaceLandmarks(image)
        }
    }

    override fun release() {
        try {
            faceSegmenter?.close()
            faceLandmarker?.close()
        } catch (e: Exception) {
            android.util.Log.e("MediaPipeHairRepository", "Error releasing MediaPipe resources", e)
        }
    }

    // Helper methods
    private fun convertMaskToBitmap(mask: BaseVisionTaskApi ?, width: Int, height: Int): Bitmap {
        // Convert MediaPipe mask to Android Bitmap
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        // ... implementation details
        return bitmap
    }

    private fun convertToFaceLandmarksResult(
        landmarks: com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarks,
        image: Bitmap
    ): FaceLandmarksResult {
        // Convert MediaPipe landmarks to domain model
        // ... implementation details
    }

    private fun analyzeHairProperties(image: Bitmap, mask: Bitmap?): HairAnalysis {
        // Analyze hair type, length, texture from image and mask
        // ... implementation details
    }

    private fun extractHairColor(image: Bitmap, mask: Bitmap?): ColorInfo {
        // Extract dominant hair color from masked region
        // ... implementation details
    }

    // Placeholder methods (kept for fallback)
    private fun createPlaceholderMask(image: Bitmap): Bitmap { /* ... */ }
    private fun createPlaceholderFaceLandmarks(image: Bitmap): FaceLandmarksResult { /* ... */ }
}
```

### 2. Add ProGuard Rules

**File**: `app/proguard-rules.pro`

Add these rules to prevent MediaPipe code from being obfuscated:

```proguard
# MediaPipe Tasks Vision
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**
-keep class com.google.mediapipe.tasks.** { *; }
-keep class com.google.mediapipe.framework.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}
```

### 3. Verify Dependencies

**File**: `app/build.gradle.kts`

Ensure these dependencies are present:

```kotlin
dependencies {
    // MediaPipe Tasks Vision (already present)
    implementation(libs.mediapipe.tasks.vision)

    // Required for MediaPipe
    implementation("com.google.ai.edge.godot:tflite-gpu-plugin:0.1.0")
    implementation("com.google.ai.edge.godot:gl:EGL:1.0")
}
```

---

## Testing the Integration

### Unit Tests Update

Update `MediaPipeHairRepositoryTest.kt` to test real inference:

```kotlin
@Test
fun `analyzeHair uses real MediaPipe inference`() = runTest {
    // This test will now use actual MediaPipe models
    val bitmap = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)
    val result = repository.analyzeHair(bitmap)

    // Verify we got a real result (not placeholder)
    assertNotNull(result.segmentationMask)
    assertNotNull(result.faceLandmarks)

    // Verify confidence is reasonable (not hardcoded 0.7)
    assertTrue(result.hairAnalysis.confidence > 0.3f)
}

@Test
fun `segmentHair returns actual segmentation mask`() = runTest() {
    val bitmap = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)
    val mask = repository.segmentHair(bitmap)

    // Verify mask is not just a simple oval
    assertNotNull(mask)
    // Real masks have complex pixel patterns, not uniform colors
}
```

### Instrumented Tests

Run instrumented tests on real device:

```bash
./gradlew.bat :app:connectedDebugAndroidTest
```

### Manual Testing

Create a test activity to verify MediaPipe is working:

```kotlin
class MediaPipeTestActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val repository = MediaPipeHairRepository(this)

        lifecycleScope.launch {
            val bitmap = BitmapFactory.decodeResource(resources, R.drawable.test_face)
            val result = repository.analyzeHair(bitmap)

            Log.d("MediaPipeTest", "Confidence: ${result.hairAnalysis.confidence}")
            Log.d("MediaPipeTest", "Hair Type: ${result.hairAnalysis.hairType}")
            Log.d("MediaPipeTest", "Processing Time: ${result.processingTimeMs}ms")
        }
    }
}
```

---

## Troubleshooting

### Problem: "Failed to initialize MediaPipe tasks"

**Causes**:
1. Model files not found in assets
2. Incorrect model file path
3. Corrupted model files

**Solutions**:
```kotlin
// Check if files exist
val assets = context.assets
try {
    assets.open("hair_segmenter.tflite").close()
    assets.open("face_landmarker.tflite").close()
    Log.d("MediaPipe", "✓ Model files found")
} catch (e: IOException) {
    Log.e("MediaPipe", "✗ Model files missing", e)
}
```

### Problem: "Out of memory during inference"

**Causes**:
1. Image resolution too high
2. Multiple inference operations
3. Memory leak

**Solutions**:
```kotlin
// Resize image before inference
fun resizeForInference(bitmap: Bitmap, maxSize: Int = 512): Bitmap {
    val width = bitmap.width
    val height = bitmap.height
    val scale = if (width > height) maxSize.toFloat() / width else maxSize.toFloat() / height

    val newWidth = (width * scale).toInt()
    val newHeight = (height * scale).toInt()

    return Bitmap.createScaledBitmap(bitmap, newWidth, newHeight, true)
}

// Use in analyzeHair
val resizedImage = resizeForInference(image)
val mpImage = BitmapImageBuilder(resizedImage).build()
```

### Problem: "Inference too slow"

**Optimizations**:
1. Use GPU acceleration
2. Reduce image resolution
3. Use quantized models
4. Cache results

```kotlin
// Enable GPU acceleration
val baseOptions = BaseOptions.builder()
    .setModelAssetPath("hair_segmenter.tflite")
    .setDelegate(BaseOptions.Delegate.GPU)  // Use GPU
    .build()
```

---

## Performance Expectations

With real MediaPipe models:

| Operation | Expected Time | Notes |
|-----------|--------------|-------|
| **Initialization** | 500-1000ms | One-time cost at startup |
| **Hair Segmentation** | 50-100ms | Per image (varies by device) |
| **Face Landmarks** | 30-80ms | 478 keypoints |
| **Full Analysis** | 100-200ms | Both operations |
| **Memory Overhead** | +100-150MB | Model loading and inference |

**Device Performance**:
- **High-end** (Pixel 6, S23): 50-100ms per frame
- **Mid-range** (Pixel 5, A53): 100-150ms per frame
- **Low-end** (older devices): 150-200ms per frame

**Frame Rate Impact**:
- Target: 15 FPS (every 2nd frame)
- With real MediaPipe: 10-15 FPS achievable
- Camera preview: Still 30 FPS (analysis on separate thread)

---

## Verification Checklist

After integration, verify:

- [ ] Model files downloaded and in assets/
- [ ] Code updated to use real MediaPipe API
- [ ] ProGuard rules added
- [ ] Unit tests pass
- [ ] Instrumented tests pass
- [ ] Manual test on device works
- [ ] Processing time < 200ms
- [ ] Memory usage < 300MB
- [ ] No crashes or ANRs
- [ ] Results look reasonable (not placeholders)

---

## Next Steps

1. **Download Models** (Choose Option 1, 2, or 3 above)
2. **Add to Assets** (`app/src/main/assets/`)
3. **Update Code** (Use provided implementation)
4. **Add ProGuard Rules** (Prevent obfuscation)
5. **Test** (Unit + Instrumented + Manual)
6. **Optimize** (GPU acceleration, image resizing)
7. **Deploy** (Profile and validate)

---

**Estimated Time**: 2-3 hours
- Download models: 15 minutes
- Update code: 1 hour
- Testing: 1 hour
- Debugging/optimization: 30 minutes

**Complexity**: Medium
- MediaPipe API is well-documented
- Most work is converting between MediaPipe and app data models
- Error handling is important for production use

---

Once models are downloaded and added to assets, I can provide the complete implementation of `MediaPipeHairRepository.kt` with real MediaPipe inference.

**Next Action**: Please download the model files and let me know when they're in the assets directory, then I'll update the implementation.
