package com.example.nativelocal_slm_app.domain.repository

import com.example.nativelocal_slm_app.domain.model.FilterEffect

/**
 * Repository interface for filter-related operations.
 * Part of domain layer - defines contract without implementation details.
 */
interface FilterRepository {
    /**
     * Load filter assets for the given filter ID.
     * Returns assets containing bitmaps and metadata, or null if not found.
     */
    suspend fun loadFilterAssets(filterId: String): FilterAssets?

    /**
     * Preload multiple filters into cache.
     * @return count of successfully loaded filters
     */
    suspend fun preloadFilters(filterIds: List<String>): Int

    /**
     * Clear the asset cache.
     */
    fun clearCache()

    /**
     * Get all predefined filters.
     */
    fun getAllPredefinedFilters(): List<FilterEffect>

    /**
     * Get filters by category.
     */
    fun getFiltersByCategory(category: com.example.nativelocal_slm_app.domain.model.FilterCategory): List<FilterEffect>

    /**
     * Find filter by ID.
     */
    fun getFilterById(id: String): FilterEffect?
}

/**
 * Filter assets data class.
 * Kept in repository package as it's a data transfer object between layers.
 */
data class FilterAssets(
    val maskOverlay: android.graphics.Bitmap? = null,    // Face mask overlay
    val eyeOverlay: android.graphics.Bitmap? = null,     // Eye makeup/overlay
    val hairOverlay: android.graphics.Bitmap? = null,    // Hair effect overlay
    val colorOverlay: androidx.compose.ui.graphics.Color? = null,    // Solid color overlay
    val metadata: com.example.nativelocal_slm_app.domain.model.FilterMetadata? = null
)
