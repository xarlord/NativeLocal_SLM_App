package com.example.nativelocal_slm_app.util

import android.graphics.Bitmap
import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import androidx.camera.core.ImageProxy
import java.io.ByteArrayOutputStream

/**
 * Utility class for image conversion operations.
 * Provides centralized, testable methods for converting between image formats.
 *
 * HIGH PRIORITY FIX #1: Extracted duplicate bitmap conversion logic
 * - Centralizes YUV to bitmap conversion
 * - Makes conversion logic testable
 * - Eliminates code duplication
 */
object ImageConversionUtils {

    /**
     * Convert ImageProxy to Bitmap using full YUV conversion.
     * Handles YUV_420_888 format from CameraX with proper color rendering.
     *
     * Use this when you need accurate color representation (e.g., for ML models).
     *
     * @param image The camera frame from CameraX
     * @return Bitmap or null if conversion fails
     */
    fun imageProxyToBitmap(image: ImageProxy): Bitmap? {
        return try {
            @Suppress("UNCHECKED_CAST")
            val nv21Buffer = yuv420ThreePlanesToNV21(
                image.image!!.planes as Array<ImageProxy.PlaneProxy>,
                image.width,
                image.height
            )
            val yuvImage = YuvImage(nv21Buffer, ImageFormat.NV21, image.width, image.height, null)
            val out = ByteArrayOutputStream()
            yuvImage.compressToJpeg(Rect(0, 0, image.width, image.height), 100, out)
            val imageBytes = out.toByteArray()
            android.graphics.BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    /**
     * Convert ImageProxy to Bitmap using Y channel only (grayscale/faster).
     * This is a simplified conversion that only extracts the Y (luminance) channel.
     *
     * Use this for quick previews when color accuracy is not critical.
     *
     * @param image The camera frame from CameraX
     * @return Bitmap (never null, but may be incomplete)
     */
    fun imageProxyToBitmapFast(image: ImageProxy): Bitmap {
        val buffer = image.planes[0].buffer
        val bytes = ByteArray(buffer.remaining())
        buffer.get(bytes)
        return android.graphics.BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
    }

    /**
     * Converts YUV_420_888 to NV21 format.
     *
     * YUV_420_888 is the format CameraX provides, with 3 separate planes:
     * - Plane 0: Y (luminance)
     * - Plane 1: U (chroma)
     * - Plane 2: V (chroma)
     *
     * NV21 is a semi-planar format with Y plane followed by interleaved VU.
     *
     * @param yuv420888planes Array of 3 planes from CameraX
     * @param width Image width
     * @param height Image height
     * @return NV21 formatted byte array
     */
    @Suppress("UNCHECKED_CAST")
    private fun yuv420ThreePlanesToNV21(
        yuv420888planes: Array<ImageProxy.PlaneProxy>,
        width: Int,
        height: Int
    ): ByteArray {
        val imageSize = width * height
        val out = ByteArray(imageSize + (imageSize / 2))
        val yBuffer = yuv420888planes[0].buffer
        val uBuffer = yuv420888planes[1].buffer
        val vBuffer = yuv420888planes[2].buffer

        // Y channel
        yBuffer.get(out, 0, imageSize)

        // U and V channels
        val pixelStride = yuv420888planes[1].pixelStride
        val rowStride = yuv420888planes[1].rowStride

        // NV21 expects V before U, so swap them
        var pos = imageSize
        for (row in 0 until height / 2) {
            for (col in 0 until width / 2) {
                val vIndex = row * rowStride + col * pixelStride
                val uIndex = row * rowStride + col * pixelStride

                out[pos++] = vBuffer.get(vIndex)
                out[pos++] = uBuffer.get(uIndex)
            }
        }

        return out
    }

    /**
     * Safely convert ImageProxy to Bitmap with null safety.
     * Returns null if image is null rather than throwing exception.
     *
     * @param image The camera frame from CameraX
     * @return Bitmap or null if image is null or conversion fails
     */
    fun imageProxyToBitmapOrNull(image: ImageProxy?): Bitmap? {
        if (image == null || image.image == null) {
            return null
        }
        return imageProxyToBitmap(image)
    }

    /**
     * Convert Bitmap to ByteArray for storage or transmission.
     *
     * @param bitmap The bitmap to convert
     * @param format Image format (default: JPEG)
     * @param quality Compression quality (0-100, default: 100)
     * @return ByteArray containing the compressed image
     */
    fun bitmapToByteArray(
        bitmap: Bitmap,
        format: android.graphics.Bitmap.CompressFormat = android.graphics.Bitmap.CompressFormat.JPEG,
        quality: Int = 100
    ): ByteArray {
        val stream = ByteArrayOutputStream()
        bitmap.compress(format, quality, stream)
        return stream.toByteArray()
    }
}
