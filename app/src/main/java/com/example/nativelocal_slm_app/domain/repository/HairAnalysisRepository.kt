package com.example.nativelocal_slm_app.domain.repository

import android.graphics.Bitmap
import com.example.nativelocal_slm_app.domain.model.FaceLandmarksResult
import com.example.nativelocal_slm_app.domain.model.HairAnalysisResult

/**
 * Repository interface for hair analysis operations using MediaPipe.
 */
interface HairAnalysisRepository {

    /**
     * Perform complete hair analysis on the given image.
     * Includes segmentation, face landmark detection, and hair characteristic analysis.
     *
     * @param image The bitmap to analyze
     * @return HairAnalysisResult containing all analysis data
     */
    suspend fun analyzeHair(image: Bitmap): HairAnalysisResult

    /**
     * Segment hair from the given image, returning a binary mask.
     *
     * @param image The bitmap to segment
     * @return Bitmap mask where white pixels are hair, black are background
     */
    suspend fun segmentHair(image: Bitmap): Bitmap?

    /**
     * Detect face landmarks in the given image.
     *
     * @param image The bitmap to analyze
     * @return FaceLandmarksResult or null if no face detected
     */
    suspend fun detectFaceLandmarks(image: Bitmap): FaceLandmarksResult?

    /**
     * Release resources and clean up MediaPipe models.
     */
    fun release()
}
