package com.example.nativelocal_slm_app.domain.model

/**
 * Represents the detected hair type based on texture and curl pattern.
 */
enum class HairType {
    STRAIGHT,
    WAVY,
    CURLY,
    COILY,
    UNKNOWN
}

/**
 * Represents the length category of the detected hair.
 */
enum class HairLength {
    SHORT,
    MEDIUM,
    LONG,
    EXTRA_LONG,
    UNKNOWN
}

/**
 * Detailed analysis of hair characteristics.
 */
data class HairAnalysis(
    val hairType: HairType,
    val hairLength: HairLength,
    val textureScore: Float, // 0f to 1f, higher means finer texture
    val volumeEstimate: Float, // 0f to 1f, higher means more volume
    val confidence: Float // 0f to 1f, confidence in the analysis
)
