package com.example.nativelocal_slm_app.domain.model

/**
 * Metadata about a filter from its JSON config.
 * Domain model - independent of data layer implementation.
 */
data class FilterMetadata(
    val author: String? = null,
    val version: String? = null,
    val description: String? = null,
    val tags: List<String> = emptyList()
)
