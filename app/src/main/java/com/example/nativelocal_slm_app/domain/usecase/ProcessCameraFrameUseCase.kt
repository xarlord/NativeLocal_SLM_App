package com.example.nativelocal_slm_app.domain.usecase

import androidx.camera.core.ImageProxy
import com.example.nativelocal_slm_app.domain.model.HairAnalysisResult
import com.example.nativelocal_slm_app.domain.model.DomainError
import com.example.nativelocal_slm_app.domain.repository.HairAnalysisRepository
import com.example.nativelocal_slm_app.util.ImageConversionUtils
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Use case for processing camera frames through the hair analysis pipeline.
 * Handles YUV to bitmap conversion and delegates to repository.
 *
 * MEDIUM PRIORITY FIX #3: Added Result<> wrapper for proper error handling.
 * BEFORE: Returned HairAnalysisResult? (null on error, no error context)
 * AFTER: Returns Result<HairAnalysisResult> with typed error information
 */
class ProcessCameraFrameUseCase(
    private val repository: HairAnalysisRepository
) {
    /**
     * Process a camera frame and return hair analysis results.
     *
     * @param image The camera frame from CameraX
     * @return Result<HairAnalysisResult> - Success with analysis data or Failure with error
     */
    suspend operator fun invoke(image: ImageProxy): Result<HairAnalysisResult> = withContext(Dispatchers.Default) {
        try {
            // Convert ImageProxy to Bitmap
            val bitmap = ImageConversionUtils.imageProxyToBitmapOrNull(image)
            if (bitmap == null) {
                return@withContext Result.failure(
                    DomainError.ImageConversionError(
                        message = "Failed to convert ImageProxy to Bitmap",
                        cause = null
                    )
                )
            }

            // Analyze hair with MediaPipe
            val analysisResult = repository.analyzeHair(bitmap)
            if (analysisResult == null) {
                return@withContext Result.failure(
                    DomainError.AnalysisError(
                        message = "Repository returned null analysis result",
                        cause = null
                    )
                )
            }

            Result.success(analysisResult)
        } catch (e: OutOfMemoryError) {
            Result.failure(
                DomainError.ImageConversionError(
                    message = "Out of memory during image conversion",
                    cause = e
                )
            )
        } catch (e: IllegalArgumentException) {
            Result.failure(
                DomainError.ImageConversionError(
                    message = "Invalid image format: ${e.message}",
                    cause = e
                )
            )
        } catch (e: Exception) {
            Result.failure(
                DomainError.AnalysisError(
                    message = "Failed to analyze hair: ${e.message}",
                    cause = e
                )
            )
        }
    }
}
