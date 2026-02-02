package com.example.nativelocal_slm_app.domain.model

/**
 * MEDIUM PRIORITY FIX #3: Domain error types for Result<> wrapper
 *
 * Provides type-safe error handling across use cases.
 * Sealed hierarchy allows exhaustive when() expressions.
 */
sealed class DomainError {
    /**
     * Error during image conversion (YUV to Bitmap).
     */
    data class ImageConversionError(val message: String, val cause: Throwable? = null) : DomainError()

    /**
     * Error during hair analysis (MediaPipe failure).
     */
    data class AnalysisError(val message: String, val cause: Throwable? = null) : DomainError()

    /**
     * Error loading filter assets from repository.
     */
    data class FilterLoadError(val filterId: String, val message: String, val cause: Throwable? = null) : DomainError()

    /**
     * Error during filter application (rendering, composition).
     */
    data class FilterApplicationError(val message: String, val cause: Throwable? = null) : DomainError()

    /**
     * File I/O error during save/load operations.
     */
    data class StorageError(val message: String, val cause: Throwable? = null) : DomainError()

    /**
     * Unknown error that doesn't fit other categories.
     */
    data class UnknownError(val message: String, val cause: Throwable? = null) : DomainError()

    /**
     * User-friendly error message for UI display.
     */
    fun getUserMessage(): String = when (this) {
        is ImageConversionError -> "Failed to process camera frame. Please try again."
        is AnalysisError -> "Hair analysis failed. Please ensure good lighting."
        is FilterLoadError -> "Could not load filter: $filterId"
        is FilterApplicationError -> "Failed to apply filter. Please try again."
        is StorageError -> "Failed to save photo. Check storage permissions."
        is UnknownError -> "An error occurred. Please try again."
    }
}
