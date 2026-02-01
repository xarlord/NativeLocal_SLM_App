package com.example.nativelocal_slm_app.domain.usecase

import android.graphics.Bitmap
import com.example.nativelocal_slm_app.domain.model.HairAnalysisResult
import com.example.nativelocal_slm_app.domain.repository.HairAnalysisRepository

/**
 * Use case for analyzing hair characteristics from a bitmap image.
 * Provides a simpler interface for non-camera image analysis.
 */
class AnalyzeHairUseCase(
    private val repository: HairAnalysisRepository
) {
    /**
     * Analyze hair from a bitmap image.
     *
     * @param image The bitmap to analyze
     * @return HairAnalysisResult with complete analysis
     */
    suspend operator fun invoke(image: Bitmap): HairAnalysisResult {
        return repository.analyzeHair(image)
    }

    /**
     * Extract hair segmentation mask only.
     *
     * @param image The bitmap to segment
     * @return Bitmap mask or null if segmentation fails
     */
    suspend fun extractMask(image: Bitmap): Bitmap? {
        return repository.segmentHair(image)
    }

    /**
     * Detect face landmarks only.
     *
     * @param image The bitmap to analyze
     * @return FaceLandmarksResult or null if no face detected
     */
    suspend fun detectLandmarks(image: Bitmap): com.example.nativelocal_slm_app.domain.model.FaceLandmarksResult? {
        return repository.detectFaceLandmarks(image)
    }
}
