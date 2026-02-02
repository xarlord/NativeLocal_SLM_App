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
import com.example.nativelocal_slm_app.domain.model.DomainError
import com.example.nativelocal_slm_app.domain.usecase.ApplyFilterUseCase
import com.example.nativelocal_slm_app.domain.usecase.ProcessCameraFrameUseCase
import com.example.nativelocal_slm_app.util.ImageConversionUtils
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.concurrent.atomic.AtomicBoolean

/**
 * ViewModel for managing camera state and processing.
 *
 * MEDIUM PRIORITY FIX #3: Updated to handle Result<> wrapper from use cases.
 * BEFORE: Ignored errors, used nullable return types
 * AFTER: Properly handles Success/Failure with typed error information
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

    // MEDIUM PRIORITY FIX #3: Added error state for UI feedback
    private val _error = MutableStateFlow<DomainError?>(null)
    val error: StateFlow<DomainError?> = _error.asStateFlow()

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
     * MEDIUM PRIORITY FIX #5: Clears reusable buffers to free memory.
     */
    fun stopCamera() {
        _cameraState.value = CameraState.Inactive
        // Clear reusable buffers to free memory when camera stops
        com.example.nativelocal_slm_app.util.ImageConversionUtils.clearReusableBuffers()
    }

    /**
     * Process a new camera frame.
     * CRITICAL FIX #2: Moved blocking operations to Dispatchers.Default
     * to prevent UI jank and frame drops.
     * HIGH PRIORITY FIX #1: Now uses ImageConversionUtils for centralized conversion logic.
     * MEDIUM PRIORITY FIX #3: Handles Result<> wrapper with proper error handling
     */
    fun onCameraFrame(imageProxy: ImageProxy) {
        if (!isProcessing.compareAndSet(false, true)) {
            imageProxy.close()
            return
        }

        viewModelScope.launch(Dispatchers.Default) {
            try {
                // Convert to bitmap for processing (BLOCKING - runs on Default dispatcher)
                // HIGH PRIORITY FIX #1: Use centralized utility
                val bitmap = ImageConversionUtils.imageProxyToBitmapOrNull(imageProxy)

                if (bitmap == null) {
                    imageProxy.close()
                    isProcessing.set(false)
                    return@launch
                }

                // MEDIUM PRIORITY FIX #3: Handle Result<HairAnalysisResult>
                when (val analysisResult = processFrameUseCase(imageProxy)) {
                    is Result.Success -> {
                        // Apply filter if one is selected
                        val filteredBitmap = if (_selectedFilter.value != null) {
                            // MEDIUM PRIORITY FIX #3: Handle Result<Bitmap>
                            when (val filterResult = applyFilterUseCase.invoke(
                                bitmap,
                                _selectedFilter.value!!,
                                analysisResult.value
                            )) {
                                is Result.Success -> filterResult.value
                                is Result.Failure -> {
                                    // Log filter error but show original bitmap
                                    _error.value = filterResult.exceptionOrNull() as? DomainError
                                    bitmap
                                }
                            }
                        } else {
                            bitmap
                        }

                        // Switch to Main dispatcher for UI updates
                        withContext(Dispatchers.Main) {
                            latestOriginalBitmap = bitmap
                            _hairAnalysisResult.value = analysisResult.value
                            _processedBitmap.value = filteredBitmap
                            _cameraState.value = CameraState.Active
                        }
                    }
                    is Result.Failure -> {
                        // MEDIUM PRIORITY FIX #3: Handle analysis errors
                        val error = analysisResult.exceptionOrNull() as? DomainError
                        withContext(Dispatchers.Main) {
                            _error.value = error
                            _cameraState.value = CameraState.Error(error?.getUserMessage() ?: "Analysis failed")
                            // Still show original bitmap even if analysis failed
                            latestOriginalBitmap = bitmap
                            _processedBitmap.value = bitmap
                        }
                    }
                }
            } catch (e: Exception) {
                // Catch unexpected errors
                val error = DomainError.UnknownError("Camera frame processing failed", e)
                withContext(Dispatchers.Main) {
                    _error.value = error
                    _cameraState.value = CameraState.Error(error.getUserMessage())
                }
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
     * Clear the current error state.
     * MEDIUM PRIORITY FIX #3: Added to allow UI to dismiss error messages.
     */
    fun clearError() {
        _error.value = null
        if (_cameraState.value is CameraState.Error) {
            _cameraState.value = CameraState.Active
        }
    }

    /**
     * CRITICAL FIX #3: Clean up bitmap resources to prevent memory leaks.
     * MEDIUM PRIORITY FIX #5: Clear reusable buffers.
     * Called when ViewModel is cleared.
     */
    override fun onCleared() {
        super.onCleared()
        // Recycle bitmaps to free memory
        latestOriginalBitmap?.recycle()
        latestOriginalBitmap = null
        _processedBitmap.value?.recycle()
        _processedBitmap.value = null
        // Clear reusable buffers
        com.example.nativelocal_slm_app.util.ImageConversionUtils.clearReusableBuffers()
    }
}

/**
 * Sealed class representing camera state.
 * MEDIUM PRIORITY FIX #3: Added Error state with message.
 */
sealed class CameraState {
    object Initializing : CameraState()
    object Active : CameraState()
    object Inactive : CameraState()
    data class Error(val message: String) : CameraState()
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
