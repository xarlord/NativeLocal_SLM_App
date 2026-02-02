# MediaPipe Setup Guide

## Overview

This app uses Google MediaPipe for real-time hair analysis and face landmark detection. The implementation is ready but requires model files to function with real ML inference.

## Current Status

✅ **MediaPipe Integration Code**: COMPLETE
- Full MediaPipe tasks-vision integration implemented
- Graceful fallback when models are missing
- Proper resource management and cleanup
- Thread-safe implementation

⚠️ **Model Files**: NOT INCLUDED
- Model files are large binary files (several MB each)
- Must be downloaded separately from Google
- Place in `app/src/main/assets/` folder

## Required Model Files

### 1. Hair Segmenter Model
**File**: `hair_segmenter.tflite`
**Purpose**: Segments hair region from camera frames
**Download**: https://developers.google.com/mediapipe/solutions/vision/hair_segmenter

### 2. Face Landmarker Model
**File**: `face_landmarker.tflite`
**Purpose**: Detects face landmarks (eyes, nose, mouth)
**Download**: https://developers.google.com/mediapipe/solutions/vision/face_landmarker

## Download Instructions

### Option 1: Download from MediaPipe Model Builder

1. Visit: https://developers.google.com/mediapipe/solutions/model_maker
2. Select "Hair Segmenter" model type
3. Choose "Android" deployment target
4. Download the `.tflite` model file
5. Rename to `hair_segmenter.tflite`
6. Place in `app/src/main/assets/`

Repeat for Face Landmarker model.

### Option 2: Use Pre-built Models (Recommended)

1. **Hair Segmenter**:
   ```bash
   # Download (link placeholder - use actual MediaPipe download URL)
   curl -L -o app/src/main/assets/hair_segmenter.tflite \
     https://storage.googleapis.com/mediapipe-models/hair_segmenter.tflite
   ```

2. **Face Landmarker**:
   ```bash
   curl -L -o app/src/main/assets/face_landmarker.tflite \
     https://storage.googleapis.com/mediapipe-models/face_landmarker.tflite
   ```

### Option 3: Copy from MediaPipe GitHub

Google provides pre-trained models in the MediaPipe GitHub repository:

1. Visit: https://github.com/google/mediapipe
2. Navigate to: `mediapipe/models/`
3. Download `hair_segmenter.tflite` and `face_landmarker.tflite`
4. Place in `app/src/main/assets/`

## Verification

After adding model files, verify the setup:

1. **Check file sizes**:
   - `hair_segmenter.tflite`: ~10-20 MB
   - `face_landmarker.tflite`: ~5-10 MB

2. **Build the app**:
   ```bash
   ./gradlew clean
   ./gradlew assembleDebug
   ```

3. **Check logcat**:
   ```
   adb logcat | grep MediaPipeHairRepository
   ```

   **Success message**:
   ```
   MediaPipeHairRepository: MediaPipe initialized successfully with real models
   ```

   **Fallback message** (models missing):
   ```
   MediaPipeHairRepository: MediaPipe initialized in fallback mode (model files missing)
   ```

## Architecture

### Implementation Structure

```
MediaPipeHairRepository
├── ImageSegmenter (Hair Segmentation)
│   ├── Input: Camera frame (Bitmap)
│   ├── Output: Segmentation mask
│   └── Model: hair_segmenter.tflite
│
└── FaceLandmarker (Face Detection)
    ├── Input: Camera frame (Bitmap)
    ├── Output: 478 face landmarks
    └── Model: face_landmarker.tflite
```

### Error Handling

The implementation includes **graceful fallback**:
- ✅ Models present → Real ML inference
- ⚠️ Models missing → Placeholder analysis (app still works)
- 📝 Clear logging indicates which mode is active

### Resource Management

Proper cleanup is implemented:
```kotlin
override fun release() {
    imageSegmenter?.close()
    faceLandmarker?.close()
    // Prevents memory leaks
}
```

Called in `MainActivity.onDestroy()` or when camera is stopped.

## Performance

**Target Requirements**:
- **Hair Segmentation**: < 100ms per frame
- **Face Detection**: < 50ms per frame
- **Total Processing**: < 150ms per frame
- **Frame Rate**: 25-30 FPS with real models

**Optimization**:
- Models run on background thread (Dispatchers.Default)
- Bitmap recycling prevents memory leaks
- LRU cache for filter assets
- Processing every 2nd frame for UI (15fps)

## Troubleshooting

### "Model file not found" Error

**Problem**: App can't find `.tflite` files
**Solution**:
1. Verify files are in `app/src/main/assets/`
2. Check filenames match exactly (case-sensitive)
3. Rebuild the app: `./gradlew clean assembleDebug`

### "Out of Memory" Error

**Problem**: Models are too large for device memory
**Solution**:
1. Use lighter model variants if available
2. Reduce image resolution before processing
3. Close other apps to free memory

### Slow Frame Rate

**Problem**: Processing takes > 150ms
**Solution**:
1. Verify running on Dispatchers.Default (background thread)
2. Reduce image resolution
3. Process every 3rd frame instead of every 2nd

### Models Not Loading

**Problem**: Logcat shows "fallback mode"
**Solution**:
1. Check model files are actually in assets folder
2. Verify build included assets: `unzip -l app/build/outputs/apk/debug/app-debug.apk | grep tflite`
3. Check file permissions: Ensure files are readable

## Testing

### Without Models (Current State)

The app works in **fallback mode**:
- Placeholder segmentation mask (simple oval)
- Placeholder face landmarks (estimated positions)
- All UI and features functional
- Lower confidence scores (0.5 vs 0.9)

### With Models (Production)

Real ML inference provides:
- Accurate hair segmentation
- Precise face landmark detection
- Higher confidence scores (0.85-0.95)
- Actual hair analysis capabilities

## Next Steps

1. **Download model files** using instructions above
2. **Add to assets folder**: `app/src/main/assets/`
3. **Rebuild app**: `./gradlew clean assembleDebug`
4. **Test on device**: Check logcat for "MediaPipe initialized successfully"
5. **Verify performance**: Should process 25-30 FPS

## Resources

- [MediaPipe Hair Segmenter](https://developers.google.com/mediapipe/solutions/vision/hair_segmenter)
- [MediaPipe Face Landmarker](https://developers.google.com/mediapipe/solutions/vision/face_landmarker)
- [MediaPipe GitHub](https://github.com/google/mediapipe)
- [Model Builder](https://developers.google.com/mediapipe/solutions/model_maker)

## License

MediaPipe models are provided by Google under their respective licenses. Refer to the MediaPipe documentation for usage rights and restrictions.
