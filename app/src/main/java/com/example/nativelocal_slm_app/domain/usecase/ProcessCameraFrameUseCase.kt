package com.example.nativelocal_slm_app.domain.usecase

import android.graphics.Bitmap
import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import androidx.camera.core.ImageProxy
import com.example.nativelocal_slm_app.domain.model.HairAnalysisResult
import com.example.nativelocal_slm_app.domain.repository.HairAnalysisRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream

/**
 * Use case for processing camera frames through the hair analysis pipeline.
 * Handles YUV to bitmap conversion and delegates to repository.
 */
class ProcessCameraFrameUseCase(
    private val repository: HairAnalysisRepository
) {
    /**
     * Process a camera frame and return hair analysis results.
     *
     * @param image The camera frame from CameraX
     * @return HairAnalysisResult or null if processing fails
     */
    suspend operator fun invoke(image: ImageProxy): HairAnalysisResult? = withContext(Dispatchers.Default) {
        try {
            val bitmap = imageProxyToBitmap(image) ?: return@withContext null
            repository.analyzeHair(bitmap)
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    /**
     * Convert ImageProxy to Bitmap.
     * Handles YUV_420_888 format from CameraX.
     */
    private fun imageProxyToBitmap(image: ImageProxy): Bitmap? {
        @Suppress("UNCHECKED_CAST")
        val nv21Buffer = yuv420ThreePlanesToNV21(image.image!!.planes as Array<ImageProxy.PlaneProxy>, image.width, image.height)
        val yuvImage = YuvImage(nv21Buffer, ImageFormat.NV21, image.width, image.height, null)
        val out = ByteArrayOutputStream()
        yuvImage.compressToJpeg(Rect(0, 0, image.width, image.height), 100, out)
        val imageBytes = out.toByteArray()
        return android.graphics.BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
    }

    /**
     * Converts YUV_420_888 to NV21 format.
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
}
