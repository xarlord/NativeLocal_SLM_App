package com.example.nativelocal_slm_app.domain.model

import android.graphics.PointF

/**
 * Represents detected face landmarks for filter application.
 */
data class FaceLandmarksResult(
    val boundingBox: BoundingBox,
    val keyPoints: Map<LandmarkType, PointF>,
    val confidence: Float,
    val timestamp: Long = System.currentTimeMillis()
)

/**
 * Bounding box around the detected face.
 */
data class BoundingBox(
    val left: Float,
    val top: Float,
    val right: Float,
    val bottom: Float
) {
    val width: Float get() = right - left
    val height: Float get() = bottom - top
    val centerX: Float get() = (left + right) / 2f
    val centerY: Float get() = (top + bottom) / 2f
}

/**
 * Types of facial landmarks detected by MediaPipe.
 */
enum class LandmarkType {
    LEFT_EYE,
    RIGHT_EYE,
    NOSE_TIP,
    MOUTH_CENTER,
    LEFT_EAR,
    RIGHT_EAR,
    FOREHEAD,
    CHIN,
    LEFT_TEMPLE,
    RIGHT_TEMPLE,
    FACE_OVAL_TOP,
    FACE_OVAL_BOTTOM,
    HAIR_TOP,
    HAIR_LEFT,
    HAIR_RIGHT
}
