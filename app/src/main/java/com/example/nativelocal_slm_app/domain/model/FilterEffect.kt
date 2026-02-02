package com.example.nativelocal_slm_app.domain.model

/**
 * Represents a filter effect that can be applied to a photo.
 * Domain model - independent of data layer implementation.
 */
data class FilterEffect(
    val id: String,
    val name: String,
    val category: FilterCategory,
    val thumbnailRes: String, // Asset path for thumbnail
    val blendMode: BlendMode = BlendMode.NORMAL,
    val defaultIntensity: Float = 1.0f
)

/**
 * Categories of filters.
 */
enum class FilterCategory {
    FACE,    // Makeup and face paint effects
    HAIR,    // Hair color and style effects
    COMBO    // Combined face and hair effects
}

/**
 * Blend modes for filter composition.
 */
enum class BlendMode {
    NORMAL,
    MULTIPLY,
    SCREEN,
    OVERLAY,
    SOFT_LIGHT,
    HARD_LIGHT,
    COLOR_DODGE,
    COLOR_BURN,
    DIFFERENCE,
    EXCLUSION
}
