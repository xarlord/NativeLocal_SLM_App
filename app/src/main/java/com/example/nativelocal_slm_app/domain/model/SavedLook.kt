package com.example.nativelocal_slm_app.domain.model

import android.net.Uri
import java.time.Instant

/**
 * Represents a saved look from a photo capture session.
 * Domain model - independent of persistence implementation.
 */
data class SavedLook(
    val id: String,
    val timestamp: Instant,
    val originalImage: Uri,
    val resultImage: Uri,
    val appliedFilters: List<String>
) {
    /**
     * Returns a human-readable timestamp.
     */
    fun getFormattedTimestamp(): String {
        val now = Instant.now()
        val diff = now.epochSecond - timestamp.epochSecond

        return when {
            diff < 60 -> "Just now"
            diff < 3600 -> "${diff / 60}m ago"
            diff < 86400 -> "${diff / 3600}h ago"
            diff < 604800 -> "${diff / 86400}d ago"
            else -> timestamp.toString().substring(0, 10) // YYYY-MM-DD
        }
    }

    /**
     * Returns the list of filter names applied.
     */
    fun getFilterNames(): List<String> {
        return appliedFilters.map { filterId ->
            PredefinedFilters.getFilterById(filterId)?.name ?: filterId
        }
    }
}
