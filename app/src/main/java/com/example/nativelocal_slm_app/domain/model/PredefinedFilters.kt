package com.example.nativelocal_slm_app.domain.model

/**
 * Predefined filter effects available in the app.
 * Domain object - provides access to all available filters.
 */
object PredefinedFilters {
    val batmanFilter = FilterEffect(
        id = "batman",
        name = "Batman",
        category = FilterCategory.FACE,
        thumbnailRes = "filters/face/batman/thumbnail.png",
        blendMode = BlendMode.NORMAL
    )

    val jokerFilter = FilterEffect(
        id = "joker",
        name = "Joker",
        category = FilterCategory.FACE,
        thumbnailRes = "filters/face/joker/thumbnail.png",
        blendMode = BlendMode.NORMAL
    )

    val skeletonFilter = FilterEffect(
        id = "skeleton",
        name = "Skeleton",
        category = FilterCategory.FACE,
        thumbnailRes = "filters/face/skeleton/thumbnail.png",
        blendMode = BlendMode.NORMAL
    )

    val tigerFaceFilter = FilterEffect(
        id = "tiger_face",
        name = "Tiger Face",
        category = FilterCategory.FACE,
        thumbnailRes = "filters/face/tiger_face/thumbnail.png",
        blendMode = BlendMode.NORMAL
    )

    val punkMohawkFilter = FilterEffect(
        id = "punk_mohawk",
        name = "Punk Mohawk",
        category = FilterCategory.HAIR,
        thumbnailRes = "filters/hair/punk_mohawk/thumbnail.png",
        blendMode = BlendMode.NORMAL
    )

    val neonGlowFilter = FilterEffect(
        id = "neon_glow",
        name = "Neon Glow",
        category = FilterCategory.HAIR,
        thumbnailRes = "filters/hair/neon_glow/thumbnail.png",
        blendMode = BlendMode.SCREEN
    )

    val fireHairFilter = FilterEffect(
        id = "fire_hair",
        name = "Fire Hair",
        category = FilterCategory.HAIR,
        thumbnailRes = "filters/hair/fire_hair/thumbnail.png",
        blendMode = BlendMode.SCREEN
    )

    val wonderWomanFilter = FilterEffect(
        id = "wonder_woman",
        name = "Wonder Woman",
        category = FilterCategory.COMBO,
        thumbnailRes = "filters/combo/wonder_woman/thumbnail.png",
        blendMode = BlendMode.NORMAL
    )

    val harleyQuinnFilter = FilterEffect(
        id = "harley_quinn",
        name = "Harley Quinn",
        category = FilterCategory.COMBO,
        thumbnailRes = "filters/combo/harley_quinn/thumbnail.png",
        blendMode = BlendMode.NORMAL
    )

    val cyberpunkFilter = FilterEffect(
        id = "cyberpunk",
        name = "Cyberpunk",
        category = FilterCategory.COMBO,
        thumbnailRes = "filters/combo/cyberpunk/thumbnail.png",
        blendMode = BlendMode.OVERLAY
    )

    /**
     * Get all available filters.
     */
    fun getAllFilters(): List<FilterEffect> = listOf(
        batmanFilter,
        jokerFilter,
        skeletonFilter,
        tigerFaceFilter,
        punkMohawkFilter,
        neonGlowFilter,
        fireHairFilter,
        wonderWomanFilter,
        harleyQuinnFilter,
        cyberpunkFilter
    )

    /**
     * Get filters by category.
     */
    fun getFiltersByCategory(category: FilterCategory): List<FilterEffect> {
        return getAllFilters().filter { it.category == category }
    }

    /**
     * Find filter by ID.
     */
    fun getFilterById(id: String): FilterEffect? {
        return getAllFilters().firstOrNull { it.id == id }
    }
}
