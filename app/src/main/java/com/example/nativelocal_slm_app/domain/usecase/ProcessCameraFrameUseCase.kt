package com.example.nativelocal_slm_app.domain.usecase

import androidx.camera.core.ImageProxy
import com.example.nativelocal_slm_app.domain.model.HairAnalysisResult
import com.example.nativelocal_slm_app.domain.repository.HairAnalysisRepository
import com.example.nativelocal_slm_app.util.ImageConversionUtils
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Use case for processing camera frames through the hair analysis pipeline.
 * Handles YUV to bitmap conversion and delegates to repository.
 *
 * HIGH PRIORITY FIX #1: Now uses ImageConversionUtils for centralized conversion logic.
 */
class ProcessCameraFrameUseCase(
    private val repository: HairAnalysisRepository
) {
    /**
     * Process a camera frame and return hair analysis results.
     *
     * @param image The camera frame from CameraX
     * @return HairAnalysisResult or null if processing fails
     */
    suspend operator fun invoke(image: ImageProxy): HairAnalysisResult? = withContext(Dispatchers.Default) {
        try {
            val bitmap = ImageConversionUtils.imageProxyToBitmapOrNull(image)
                ?: return@withContext null
            repository.analyzeHair(bitmap)
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}
