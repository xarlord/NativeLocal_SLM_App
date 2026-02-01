package com.example.nativelocal_slm_app.domain.model

import android.graphics.Bitmap

/**
 * Complete result from hair analysis including segmentation mask,
 * hair characteristics, and face landmarks.
 */
data class HairAnalysisResult(
    val segmentationMask: Bitmap?,
    val hairAnalysis: HairAnalysis,
    val hairColor: ColorInfo,
    val faceLandmarks: FaceLandmarksResult?,
    val processingTimeMs: Long
) {
    /**
     * Returns true if the analysis confidence is above a usable threshold.
     */
    fun isConfident(): Boolean = hairAnalysis.confidence > 0.5f

    /**
     * Returns true if face landmarks were successfully detected.
     */
    fun hasFaceLandmarks(): Boolean = faceLandmarks != null && faceLandmarks!!.confidence > 0.5f
}
