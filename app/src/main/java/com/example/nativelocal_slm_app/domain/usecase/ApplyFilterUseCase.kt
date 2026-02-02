package com.example.nativelocal_slm_app.domain.usecase

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Rect
import com.example.nativelocal_slm_app.domain.repository.FilterRepository
import com.example.nativelocal_slm_app.domain.model.FilterCategory
import com.example.nativelocal_slm_app.domain.model.FilterEffect
import com.example.nativelocal_slm_app.domain.model.PredefinedFilters
import com.example.nativelocal_slm_app.domain.model.HairAnalysisResult
import com.example.nativelocal_slm_app.domain.repository.HairAnalysisRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Use case for applying filter effects to camera frames.
 * Loads filter assets and composes them with the camera frame.
 */
class ApplyFilterUseCase(
    private val filterRepository: FilterRepository,
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
        val assets = filterRepository.loadFilterAssets(filter.id)

        // Apply filter based on category
        when (filter.category) {
            FilterCategory.FACE -> applyFaceFilter(canvas, analysisResult, assets, filter)
            FilterCategory.HAIR -> applyHairFilter(canvas, analysisResult, assets, filter)
            FilterCategory.COMBO -> applyComboFilter(canvas, analysisResult, assets, filter)
        }

        resultBitmap
    }

    /**
     * Apply face filter (mask and eye makeup).
     * HIGH PRIORITY FIX #3: Refactored into smaller, testable methods.
     */
    private fun applyFaceFilter(
        canvas: Canvas,
        analysisResult: HairAnalysisResult,
        assets: com.example.nativelocal_slm_app.domain.repository.FilterAssets?,
        filter: FilterEffect
    ) {
        val faceLandmarks = analysisResult.faceLandmarks ?: return

        // Apply mask overlay
        assets?.maskOverlay?.let { maskBitmap ->
            val scaledMask = scaleMaskForFace(maskBitmap, faceLandmarks.boundingBox)
            val position = calculateMaskPosition(scaledMask, faceLandmarks.boundingBox)
            drawMaskOnCanvas(canvas, scaledMask, position)
        }

        // Apply eye makeup
        assets?.eyeOverlay?.let { eyeBitmap ->
            applyEyeMakeup(canvas, eyeBitmap, faceLandmarks)
        }
    }

    /**
     * Scale mask bitmap to fit face bounding box.
     * HIGH PRIORITY FIX #3: Extracted from applyFaceFilter for testability.
     */
    private fun scaleMaskForFace(maskBitmap: Bitmap, boundingBox: com.example.nativelocal_slm_app.domain.model.BoundingBox): Bitmap {
        val scaleFactor = (boundingBox.width * 1.4f) / maskBitmap.width
        val scaledWidth = (maskBitmap.width * scaleFactor).toInt()
        val scaledHeight = (maskBitmap.height * scaleFactor).toInt()

        return if (scaledWidth > 0 && scaledHeight > 0) {
            Bitmap.createScaledBitmap(maskBitmap, scaledWidth, scaledHeight, true)
        } else {
            maskBitmap
        }
    }

    /**
     * Calculate position for mask overlay on face.
     * HIGH PRIORITY FIX #3: Extracted from applyFaceFilter for testability.
     */
    private fun calculateMaskPosition(
        maskBitmap: Bitmap,
        boundingBox: com.example.nativelocal_slm_app.domain.model.BoundingBox
    ): Position {
        val left = (boundingBox.centerX - maskBitmap.width / 2f).toInt()
        val top = (boundingBox.centerY * 0.7f - maskBitmap.height / 2f).toInt()
        return Position(left.toFloat(), top.toFloat())
    }

    /**
     * Draw mask bitmap on canvas at specified position.
     * HIGH PRIORITY FIX #3: Extracted from applyFaceFilter for reusability.
     */
    private fun drawMaskOnCanvas(canvas: Canvas, maskBitmap: Bitmap, position: Position) {
        val paint = Paint().apply {
            isFilterBitmap = true
            alpha = 230
            xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_OVER)
        }
        canvas.drawBitmap(maskBitmap, position.x, position.y, paint)
    }

    /**
     * Apply eye makeup to both eyes.
     * HIGH PRIORITY FIX #3: Extracted from applyFaceFilter for clarity.
     */
    private fun applyEyeMakeup(
        canvas: Canvas,
        eyeBitmap: Bitmap,
        faceLandmarks: com.example.nativelocal_slm_app.domain.model.FaceLandmarksResult
    ) {
        val leftEye = faceLandmarks.keyPoints[com.example.nativelocal_slm_app.domain.model.LandmarkType.LEFT_EYE]
        val rightEye = faceLandmarks.keyPoints[com.example.nativelocal_slm_app.domain.model.LandmarkType.RIGHT_EYE]

        val paint = Paint().apply {
            isFilterBitmap = true
            alpha = 200
            xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_OVER)
        }

        val eyeSize = (faceLandmarks.boundingBox.width * 0.15f).toInt()

        // Apply to left eye
        leftEye?.let { eyePoint ->
            drawEyeMakeup(canvas, eyeBitmap, eyePoint, eyeSize, paint)
        }

        // Apply to right eye
        rightEye?.let { eyePoint ->
            drawEyeMakeup(canvas, eyeBitmap, eyePoint, eyeSize, paint)
        }
    }

    /**
     * Draw eye makeup at a single eye position.
     * HIGH PRIORITY FIX #3: Extracted for reusability and testability.
     */
    private fun drawEyeMakeup(
        canvas: Canvas,
        eyeBitmap: Bitmap,
        eyePosition: android.graphics.PointF,
        eyeSize: Int,
        paint: Paint
    ) {
        val scaledEye = Bitmap.createScaledBitmap(eyeBitmap, eyeSize, eyeSize, true)
        val left = (eyePosition.x - eyeSize / 2f).toInt()
        val top = (eyePosition.y - eyeSize / 2f).toInt()
        canvas.drawBitmap(scaledEye, left.toFloat(), top.toFloat(), paint)
    }

    /**
     * Data class for position coordinates.
     * HIGH PRIORITY FIX #3: Added for clearer method signatures.
     */
    private data class Position(val x: Float, val y: Float)

    /**
     * Apply hair filter using segmentation mask.
     * HIGH PRIORITY FIX #3: Refactored for clarity and testability.
     */
    private fun applyHairFilter(
        canvas: Canvas,
        analysisResult: HairAnalysisResult,
        assets: com.example.nativelocal_slm_app.domain.repository.FilterAssets?,
        filter: FilterEffect
    ) {
        val mask = analysisResult.segmentationMask ?: return

        // Create temporary bitmap for hair overlay
        val tempBitmap = Bitmap.createBitmap(canvas.width, canvas.height, Bitmap.Config.ARGB_8888)
        val tempCanvas = Canvas(tempBitmap)

        // Draw hair overlay with blend mode
        assets?.hairOverlay?.let { hairOverlay ->
            val paint = createHairPaint(filter.blendMode)
            val scaledOverlay = Bitmap.createScaledBitmap(hairOverlay, canvas.width, canvas.height, true)
            tempCanvas.drawBitmap(scaledOverlay, 0f, 0f, paint)
        }

        // Apply segmentation mask to limit filter to hair region
        applySegmentationMask(tempCanvas, mask)

        // Composite filtered hair onto main canvas
        compositeHairOverlay(canvas, tempBitmap)
    }

    /**
     * Create paint for hair overlay based on blend mode.
     * HIGH PRIORITY FIX #3: Extracted for testability and reusability.
     */
    private fun createHairPaint(blendMode: com.example.nativelocal_slm_app.domain.model.BlendMode): Paint {
        return Paint().apply {
            isFilterBitmap = true
            alpha = 180
            xfermode = when (blendMode) {
                com.example.nativelocal_slm_app.domain.model.BlendMode.SCREEN ->
                    PorterDuffXfermode(PorterDuff.Mode.SCREEN)
                com.example.nativelocal_slm_app.domain.model.BlendMode.OVERLAY ->
                    PorterDuffXfermode(PorterDuff.Mode.OVERLAY)
                com.example.nativelocal_slm_app.domain.model.BlendMode.MULTIPLY ->
                    PorterDuffXfermode(PorterDuff.Mode.MULTIPLY)
                else -> PorterDuffXfermode(PorterDuff.Mode.SRC_OVER)
            }
        }
    }

    /**
     * Apply segmentation mask to canvas (limits effect to hair region).
     * HIGH PRIORITY FIX #3: Extracted for clarity.
     */
    private fun applySegmentationMask(canvas: Canvas, mask: Bitmap) {
        val maskPaint = Paint().apply {
            xfermode = PorterDuffXfermode(PorterDuff.Mode.DST_IN)
            alpha = 255
        }
        canvas.drawBitmap(mask, 0f, 0f, maskPaint)
    }

    /**
     * Composite hair overlay onto main canvas.
     * HIGH PRIORITY FIX #3: Extracted for reusability.
     */
    private fun compositeHairOverlay(canvas: Canvas, overlayBitmap: Bitmap) {
        val compositePaint = Paint().apply {
            xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_OVER)
            alpha = 200
        }
        canvas.drawBitmap(overlayBitmap, 0f, 0f, compositePaint)
    }

    private fun applyComboFilter(
        canvas: Canvas,
        analysisResult: HairAnalysisResult,
        assets: com.example.nativelocal_slm_app.domain.repository.FilterAssets?,
        filter: FilterEffect
    ) {
        // Apply both face and hair filters
        applyFaceFilter(canvas, analysisResult, assets, filter)
        applyHairFilter(canvas, analysisResult, assets, filter)
    }
}
