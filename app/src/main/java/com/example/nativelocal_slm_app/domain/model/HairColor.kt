package com.example.nativelocal_slm_app.domain.model

import androidx.compose.ui.graphics.Color

/**
 * Represents the color information extracted from hair.
 */
data class ColorInfo(
    val primaryColor: Color,
    val secondaryColor: Color? = null,
    val brightness: Float, // 0f to 1f
    val saturation: Float // 0f to 1f
)

/**
 * Represents a custom hair color with application settings.
 */
data class HairColor(
    val id: String,
    val name: String,
    val baseColor: Color,
    val highlights: List<Color> = emptyList(),
    val isGradient: Boolean = false,
    val gradientStyle: GradientStyle? = null
)

/**
 * Gradient styles for hair coloring effects.
 */
enum class GradientStyle {
    OMBRE,
    BALAYAGE,
    SOMBRÉ,
    TWO_TONE
}

/**
 * Adjustments that can be made to a hair color.
 */
data class ColorAdjustments(
    val brightness: Float = 0f, // -1f to 1f
    val saturation: Float = 0f, // -1f to 1f
    val hue: Float = 0f // -180f to 180f
)
