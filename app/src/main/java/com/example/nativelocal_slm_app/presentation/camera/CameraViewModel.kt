package com.example.nativelocal_slm_app.presentation.camera

import android.graphics.Bitmap
import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import androidx.camera.core.ImageProxy
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.nativelocal_slm_app.domain.model.FilterEffect
import com.example.nativelocal_slm_app.domain.model.PredefinedFilters
import com.example.nativelocal_slm_app.domain.model.HairAnalysisResult
import com.example.nativelocal_slm_app.domain.usecase.ApplyFilterUseCase
import com.example.nativelocal_slm_app.domain.usecase.ProcessCameraFrameUseCase
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.util.concurrent.atomic.AtomicBoolean

/**
 * ViewModel for managing camera state and processing.
 */
class CameraViewModel(
    private val processFrameUseCase: ProcessCameraFrameUseCase,
    private val applyFilterUseCase: ApplyFilterUseCase
) : ViewModel() {

    private val _cameraState = MutableStateFlow<CameraState>(CameraState.Initializing)
    val cameraState: StateFlow<CameraState> = _cameraState.asStateFlow()

    private val _hairAnalysisResult = MutableStateFlow<HairAnalysisResult?>(null)
    val hairAnalysisResult: StateFlow<HairAnalysisResult?> = _hairAnalysisResult.asStateFlow()

    private val _selectedFilter = MutableStateFlow<FilterEffect?>(null)
    val selectedFilter: StateFlow<FilterEffect?> = _selectedFilter.asStateFlow()

    private val _processedBitmap = MutableStateFlow<Bitmap?>(null)
    val processedBitmap: StateFlow<Bitmap?> = _processedBitmap.asStateFlow()

    private val _capturedPhoto = MutableStateFlow<CapturedPhoto?>(null)
    val capturedPhoto: StateFlow<CapturedPhoto?> = _capturedPhoto.asStateFlow()

    private val isProcessing = AtomicBoolean(false)
    private var latestOriginalBitmap: Bitmap? = null

    /**
     * Start the camera stream.
     */
    fun startCamera() {
        _cameraState.value = CameraState.Active
    }

    /**
     * Stop the camera stream.
     */
    fun stopCamera() {
        _cameraState.value = CameraState.Inactive
    }

    /**
     * Process a new camera frame.
     * CRITICAL FIX #2: Moved blocking operations to Dispatchers.Default
     * to prevent UI jank and frame drops.
     */
    fun onCameraFrame(imageProxy: ImageProxy) {
        if (!isProcessing.compareAndSet(false, true)) {
            imageProxy.close()
            return
        }

        viewModelScope.launch(Dispatchers.Default) {
            try {
                // Convert to bitmap for processing (BLOCKING - runs on Default dispatcher)
                val bitmap = imageProxyToBitmap(imageProxy)

                // Analyze the frame
                val result = processFrameUseCase(imageProxy)

                // Apply filter if one is selected
                val filteredBitmap = if (result != null && _selectedFilter.value != null) {
                    applyFilterUseCase.invoke(
                        bitmap,
                        _selectedFilter.value!!,
                        result
                    )
                } else {
                    bitmap
                }

                // Switch to Main dispatcher for UI updates
                withContext(Dispatchers.Main) {
                    latestOriginalBitmap = bitmap
                    result?.let {
                        _hairAnalysisResult.value = it
                    }
                    _processedBitmap.value = filteredBitmap
                }
            } catch (e: Exception) {
                e.printStackTrace()
            } finally {
                imageProxy.close()
                isProcessing.set(false)
            }
        }
    }

    /**
     * Select a filter to apply.
     */
    fun selectFilter(filter: FilterEffect?) {
        _selectedFilter.value = filter
    }

    /**
     * Capture the current frame as a photo.
     */
    fun capturePhoto() {
        val original = latestOriginalBitmap ?: return
        val processed = _processedBitmap.value
        val filter = _selectedFilter.value
        val analysis = _hairAnalysisResult.value

        _capturedPhoto.value = CapturedPhoto(
            originalImage = original,
            processedImage = processed ?: original,
            appliedFilter = filter?.id,
            analysisResult = analysis
        )
    }

    /**
     * Clear the captured photo.
     */
    fun clearCapturedPhoto() {
        _capturedPhoto.value = null
    }

    /**
     * Convert ImageProxy to Bitmap.
     */
    private fun imageProxyToBitmap(imageProxy: ImageProxy): Bitmap {
        val buffer = imageProxy.planes[0].buffer
        val bytes = ByteArray(buffer.remaining())
        buffer.get(bytes)

        val bitmap = android.graphics.BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        return bitmap
    }
}

/**
 * Sealed class representing camera state.
 */
sealed class CameraState {
    object Initializing : CameraState()
    object Active : CameraState()
    object Inactive : CameraState()
    object Error : CameraState()
}

/**
 * Data class representing a captured photo.
 */
data class CapturedPhoto(
    val originalImage: Bitmap,
    val processedImage: Bitmap,
    val appliedFilter: String?,
    val analysisResult: HairAnalysisResult?
)
