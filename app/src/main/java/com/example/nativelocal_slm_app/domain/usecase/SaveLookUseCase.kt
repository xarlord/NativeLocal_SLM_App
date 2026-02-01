package com.example.nativelocal_slm_app.domain.usecase

import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import com.example.nativelocal_slm_app.data.model.SavedLook
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.time.Instant
import java.util.UUID

/**
 * Use case for saving captured looks to device storage.
 * Handles file I/O and creates SavedLook records.
 */
class SaveLookUseCase(
    private val context: Context
) {
    /**
     * Save a captured look to device storage.
     *
     * @param originalImage The original camera frame
     * @param resultImage The processed image with filters applied
     * @param appliedFilters List of filters that were applied
     * @return SavedLook object with file URIs
     */
    suspend operator fun invoke(
        originalImage: Bitmap,
        resultImage: Bitmap,
        appliedFilters: List<String>
    ): Result<SavedLook> = withContext(Dispatchers.IO) {
        try {
            val lookId = UUID.randomUUID().toString()
            val timestamp = Instant.now()

            // Save images to app-specific storage
            val originalUri = saveBitmap(originalImage, "look_${lookId}_original.jpg")
            val resultUri = saveBitmap(resultImage, "look_${lookId}_result.jpg")

            val savedLook = SavedLook(
                id = lookId,
                timestamp = timestamp,
                originalImage = originalUri,
                resultImage = resultUri,
                appliedFilters = appliedFilters
            )

            Result.success(savedLook)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    private fun saveBitmap(bitmap: Bitmap, filename: String): Uri {
        val directory = File(context.filesDir, "saved_looks")
        if (!directory.exists()) {
            directory.mkdirs()
        }

        val file = File(directory, filename)
        FileOutputStream(file).use { out ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out)
        }

        return Uri.fromFile(file)
    }

    /**
     * Delete a saved look from storage.
     */
    suspend fun deleteLook(look: SavedLook): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            context.contentResolver.delete(look.originalImage, null, null)
            context.contentResolver.delete(look.resultImage, null, null)
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Load all saved looks from storage.
     */
    suspend fun loadSavedLooks(): Result<List<SavedLook>> = withContext(Dispatchers.IO) {
        try {
            val directory = File(context.filesDir, "saved_looks")
            if (!directory.exists()) {
                return@withContext Result.success(emptyList())
            }

            // Scan directory for saved look pairs
            val files = directory.listFiles()?.toList() ?: emptyList()
            val looks = files
                .filter { it.name.endsWith("_result.jpg") }
                .mapNotNull { file ->
                    val lookId = file.name.removeSuffix("_result.jpg").removePrefix("look_")
                    val originalFile = File(directory, "look_${lookId}_original.jpg")

                    if (originalFile.exists()) {
                        SavedLook(
                            id = lookId,
                            timestamp = Instant.ofEpochMilli(file.lastModified()),
                            originalImage = Uri.fromFile(originalFile),
                            resultImage = Uri.fromFile(file),
                            appliedFilters = emptyList()
                        )
                    } else {
                        null
                    }
                }
                .sortedByDescending { it.timestamp }

            Result.success(looks)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
