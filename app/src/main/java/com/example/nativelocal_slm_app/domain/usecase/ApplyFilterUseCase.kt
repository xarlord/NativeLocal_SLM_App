package com.example.nativelocal_slm_app.domain.usecase

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Rect
import com.example.nativelocal_slm_app.data.repository.FilterAssetsRepository
import com.example.nativelocal_slm_app.data.model.FilterCategory
import com.example.nativelocal_slm_app.data.model.FilterEffect
import com.example.nativelocal_slm_app.data.model.PredefinedFilters
import com.example.nativelocal_slm_app.domain.model.HairAnalysisResult
import com.example.nativelocal_slm_app.domain.repository.HairAnalysisRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Use case for applying filter effects to camera frames.
 * Loads filter assets and composes them with the camera frame.
 */
class ApplyFilterUseCase(
    private val filterAssetsRepository: FilterAssetsRepository,
    private val hairAnalysisRepository: HairAnalysisRepository
) {
    /**
     * Apply a filter effect to the original image.
     */
    suspend operator fun invoke(
        originalImage: Bitmap,
        filter: FilterEffect,
        analysisResult: HairAnalysisResult
    ): Bitmap = withContext(Dispatchers.Default) {
        // Create a mutable copy of the original image
        val resultBitmap = originalImage.copy(Bitmap.Config.ARGB_8888, true)
        val canvas = Canvas(resultBitmap)

        // Load filter assets
        val assets = filterAssetsRepository.loadFilterAssets(filter.id)

        // Apply filter based on category
        when (filter.category) {
            FilterCategory.FACE -> applyFaceFilter(canvas, analysisResult, assets, filter)
            FilterCategory.HAIR -> applyHairFilter(canvas, analysisResult, assets, filter)
            FilterCategory.COMBO -> applyComboFilter(canvas, analysisResult, assets, filter)
        }

        resultBitmap
    }

    private fun applyFaceFilter(
        canvas: Canvas,
        analysisResult: HairAnalysisResult,
        assets: com.example.nativelocal_slm_app.data.model.FilterAssets?,
        filter: FilterEffect
    ) {
        val faceLandmarks = analysisResult.faceLandmarks ?: return

        // Draw mask overlay
        assets?.maskOverlay?.let { maskBitmap ->
            val boundingBox = faceLandmarks.boundingBox

            val paint = Paint().apply {
                isFilterBitmap = true
                alpha = 230
                xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_OVER)
            }

            // Scale and position mask overlay to fit face
            val scaleFactor = (boundingBox.width * 1.4f) / maskBitmap.width
            val scaledWidth = (maskBitmap.width * scaleFactor).toInt()
            val scaledHeight = (maskBitmap.height * scaleFactor).toInt()

            if (scaledWidth > 0 && scaledHeight > 0) {
                val scaledMask = Bitmap.createScaledBitmap(maskBitmap, scaledWidth, scaledHeight, true)

                // Position centered on face
                val left = (boundingBox.centerX - scaledWidth / 2f).toInt()
                val top = (boundingBox.centerY * 0.7f - scaledHeight / 2f).toInt()

                canvas.drawBitmap(scaledMask, left.toFloat(), top.toFloat(), paint)
            }
        }

        // Draw eye makeup overlay
        assets?.eyeOverlay?.let { eyeBitmap ->
            val leftEye = faceLandmarks.keyPoints[com.example.nativelocal_slm_app.domain.model.LandmarkType.LEFT_EYE]
            val rightEye = faceLandmarks.keyPoints[com.example.nativelocal_slm_app.domain.model.LandmarkType.RIGHT_EYE]

            val paint = Paint().apply {
                isFilterBitmap = true
                alpha = 200
                xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_OVER)
            }

            val eyeSize = (faceLandmarks.boundingBox.width * 0.15f).toInt()

            leftEye?.let {
                val scaledEye = Bitmap.createScaledBitmap(eyeBitmap, eyeSize, eyeSize, true)
                val left = (it.x - eyeSize / 2f).toInt()
                val top = (it.y - eyeSize / 2f).toInt()
                canvas.drawBitmap(scaledEye, left.toFloat(), top.toFloat(), paint)
            }

            rightEye?.let {
                val scaledEye = Bitmap.createScaledBitmap(eyeBitmap, eyeSize, eyeSize, true)
                val left = (it.x - eyeSize / 2f).toInt()
                val top = (it.y - eyeSize / 2f).toInt()
                canvas.drawBitmap(scaledEye, left.toFloat(), top.toFloat(), paint)
            }
        }
    }

    private fun applyHairFilter(
        canvas: Canvas,
        analysisResult: HairAnalysisResult,
        assets: com.example.nativelocal_slm_app.data.model.FilterAssets?,
        filter: FilterEffect
    ) {
        val mask = analysisResult.segmentationMask ?: return

        // Create a temporary bitmap for the hair overlay
        val tempBitmap = Bitmap.createBitmap(canvas.width, canvas.height, Bitmap.Config.ARGB_8888)
        val tempCanvas = Canvas(tempBitmap)

        // Draw hair overlay from assets
        assets?.hairOverlay?.let { hairOverlay ->
            val paint = Paint().apply {
                isFilterBitmap = true
                alpha = 180
                when (filter.blendMode) {
                    com.example.nativelocal_slm_app.data.model.BlendMode.SCREEN ->
                        xfermode = PorterDuffXfermode(PorterDuff.Mode.SCREEN)
                    com.example.nativelocal_slm_app.data.model.BlendMode.OVERLAY ->
                        xfermode = PorterDuffXfermode(PorterDuff.Mode.OVERLAY)
                    com.example.nativelocal_slm_app.data.model.BlendMode.MULTIPLY ->
                        xfermode = PorterDuffXfermode(PorterDuff.Mode.MULTIPLY)
                    else -> xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_OVER)
                }
            }

            // Scale overlay to match image size
            val scaledOverlay = Bitmap.createScaledBitmap(hairOverlay, canvas.width, canvas.height, true)
            tempCanvas.drawBitmap(scaledOverlay, 0f, 0f, paint)
        }

        // Use segmentation mask to apply filter only to hair region
        val maskPaint = Paint().apply {
            xfermode = PorterDuffXfermode(PorterDuff.Mode.DST_IN)
            alpha = 255
        }

        tempCanvas.drawBitmap(mask, 0f, 0f, maskPaint)

        // Composite the filtered hair onto the canvas
        val compositePaint = Paint().apply {
            xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_OVER)
            alpha = 200
        }

        canvas.drawBitmap(tempBitmap, 0f, 0f, compositePaint)
    }

    private fun applyComboFilter(
        canvas: Canvas,
        analysisResult: HairAnalysisResult,
        assets: com.example.nativelocal_slm_app.data.model.FilterAssets?,
        filter: FilterEffect
    ) {
        // Apply both face and hair filters
        applyFaceFilter(canvas, analysisResult, assets, filter)
        applyHairFilter(canvas, analysisResult, assets, filter)
    }
}
