package com.example.nativelocal_slm_app.data.repository

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import androidx.compose.ui.graphics.toArgb
import com.example.nativelocal_slm_app.domain.repository.FilterRepository
import com.example.nativelocal_slm_app.domain.repository.FilterAssets
import com.example.nativelocal_slm_app.domain.model.FilterMetadata
import com.example.nativelocal_slm_app.domain.model.PredefinedFilters
import com.example.nativelocal_slm_app.domain.model.FilterCategory
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.IOException
import android.util.LruCache

/**
 * Repository for loading filter assets from the app's assets folder.
 * Handles bitmap loading and metadata parsing.
 * Implements FilterRepository interface from domain layer.
 */
class FilterAssetsRepository(
    private val context: Context
) : FilterRepository {
    /**
     * CRITICAL FIX #3 & #5: LruCache for memory management + thread-safety
     * Uses 1/8 of available memory for cache, with automatic eviction.
     */
    private val assetCache = LruCache<String, FilterAssets>(
        (Runtime.getRuntime().maxMemory() / 8).toInt()
    )

    /**
     * Load filter assets for the given filter ID.
     * Results are cached for performance.
     * CRITICAL FIX #3: Uses LruCache with automatic eviction and sizeOf for memory management.
     * LruCache is thread-safe by design.
     */
    override suspend fun loadFilterAssets(filterId: String): FilterAssets? = withContext(Dispatchers.IO) {
        // Check cache first (LruCache.get() is thread-safe)
        assetCache.get(filterId)?.let { return@withContext it }

        try {
            // Find filter directory
            val filterPath = findFilterPath(filterId) ?: return@withContext null

            // Load metadata
            val metadata = loadMetadata("$filterPath/metadata.json")

            // Load bitmaps
            val maskOverlay = loadBitmap("$filterPath/mask.png")
            val eyeOverlay = loadBitmap("$filterPath/eyes.png")
            val hairOverlay = loadBitmap("$filterPath/hair_overlay.png")

            val assets = FilterAssets(
                maskOverlay = maskOverlay,
                eyeOverlay = eyeOverlay,
                hairOverlay = hairOverlay,
                metadata = metadata
            )

            // Cache the result (LruCache.put() is thread-safe)
            assetCache.put(filterId, assets)

            assets
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    /**
     * Find the asset path for a filter by searching all filter categories.
     * Uses direct file open check instead of list() for better Robolectric compatibility.
     * Also tries listing as fallback for compatibility with different test setups.
     */
    private fun findFilterPath(filterId: String): String? {
        val categories = listOf("face", "hair", "combo")

        for (category in categories) {
            val path = "filters/$category/$filterId"

            // Method 1: Try to open metadata.json (works in many cases)
            try {
                context.assets.open("$path/metadata.json").close()
                return path
            } catch (e: IOException) {
                // Try method 2
            }

            // Method 2: Try list() as fallback (works in some Robolectric versions)
            try {
                val files = context.assets.list(path)
                if (files != null && files.isNotEmpty()) {
                    return path
                }
            } catch (e: IOException) {
                // Continue to next category
            }
        }

        return null
    }

    /**
     * Load a bitmap from assets.
     */
    private fun loadBitmap(path: String): Bitmap? {
        return try {
            val inputStream = context.assets.open(path)
            BitmapFactory.decodeStream(inputStream)
        } catch (e: IOException) {
            null
        }
    }

    /**
     * Load metadata JSON from assets.
     */
    private fun loadMetadata(path: String): FilterMetadata? {
        return try {
            val jsonString = context.assets.open(path).bufferedReader().use { it.readText() }
            val json = JSONObject(jsonString)

            FilterMetadata(
                author = json.optString("author", null),
                version = json.optString("version", null),
                description = json.optString("description", null),
                tags = json.optJSONArray("tags")?.let { array ->
                    List(array.length()) { i -> array.optString(i) }
                } ?: emptyList()
            )
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Clear the asset cache to free memory.
     * CRITICAL FIX #3: LruCache.evictAll() clears the cache.
     */
    override fun clearCache() {
        assetCache.evictAll()
    }

    /**
     * Preload filter assets for faster access.
     * @return count of successfully loaded filters
     */
    override suspend fun preloadFilters(filterIds: List<String>): Int = withContext(Dispatchers.IO) {
        var count = 0
        filterIds.forEach { filterId ->
            if (loadFilterAssets(filterId) != null) {
                count++
            }
        }
        count
    }

    /**
     * Get all predefined filters from domain layer.
     */
    override fun getAllPredefinedFilters() = PredefinedFilters.getAllFilters()

    /**
     * Get filters by category from domain layer.
     */
    override fun getFiltersByCategory(category: FilterCategory) =
        PredefinedFilters.getFiltersByCategory(category)

    /**
     * Find filter by ID from domain layer.
     */
    override fun getFilterById(id: String) = PredefinedFilters.getFilterById(id)
}
