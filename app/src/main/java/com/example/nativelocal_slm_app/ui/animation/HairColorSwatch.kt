package com.example.nativelocal_slm_app.ui.animation

import androidx.compose.ui.graphics.Color

/**
 * Predefined hair color swatches for color picker.
 */
data class HairColorSwatch(
    val name: String,
    val color: Color
)

object PredefinedHairColors {
    fun getAllColors(): List<HairColorSwatch> = listOf(
        HairColorSwatch("Natural Black", Color(0xFF1A1A1A)),
        HairColorSwatch("Dark Brown", Color(0xFF3D2314)),
        HairColorSwatch("Medium Brown", Color(0xFF6B4423)),
        HairColorSwatch("Light Brown", Color(0xFFA67B5B)),
        HairColorSwatch("Blonde", Color(0xFFE6BE8A)),
        HairColorSwatch("Platinum", Color(0xFFE8DCC4)),
        HairColorSwatch("Red", Color(0xFF8B0000)),
        HairColorSwatch("Copper", Color(0xFFB87333)),
        HairColorSwatch("Auburn", Color(0xFFA52A2A)),
        HairColorSwatch("Pink", Color(0xFFFF69B4)),
        HairColorSwatch("Purple", Color(0xFF800080)),
        HairColorSwatch("Blue", Color(0xFF0000FF)),
        HairColorSwatch("Green", Color(0xFF228B22))
    )
}
