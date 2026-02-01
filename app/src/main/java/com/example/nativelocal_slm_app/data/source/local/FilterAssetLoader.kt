package com.example.nativelocal_slm_app.data.source.local

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import java.io.IOException

/**
 * Utility class for loading filter assets from the app's assets folder.
 */
object FilterAssetLoader {

    /**
     * Load a bitmap from the assets folder.
     *
     * @param context Application context
     * @param path Path to the asset file (e.g., "filters/face/batman/mask.png")
     * @return Bitmap or null if loading fails
     */
    fun loadBitmap(context: Context, path: String): Bitmap? {
        return try {
            val inputStream = context.assets.open(path)
            BitmapFactory.decodeStream(inputStream)
        } catch (e: IOException) {
            e.printStackTrace()
            null
        }
    }

    /**
     * Check if an asset file exists.
     *
     * @param context Application context
     * @param path Path to check
     * @return true if file exists, false otherwise
     */
    fun assetExists(context: Context, path: String): Boolean {
        return try {
            val list = context.assets.list(path.substringBeforeLast("/"))
            list?.contains(path.substringAfterLast("/")) ?: false
        } catch (e: IOException) {
            false
        }
    }

    /**
     * List all directories in a given path.
     *
     * @param context Application context
     * @param path Path to list (e.g., "filters/face")
     * @return List of directory names
     */
    fun listDirectories(context: Context, path: String): List<String> {
        return try {
            context.assets.list(path)?.toList() ?: emptyList()
        } catch (e: IOException) {
            emptyList()
        }
    }
}
