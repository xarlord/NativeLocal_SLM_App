package com.example.nativelocal_slm_app.domain.model

import android.graphics.PointF
import androidx.compose.ui.graphics.Color
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Additional tests for domain models to increase coverage.
 * Focuses on edge cases, boundary conditions, and comprehensive scenarios.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class DomainModelExpandedTest {

    // ========== BoundingBox Edge Cases ==========
    @Test
    fun `BoundingBox with zero dimensions`() {
        val bbox = BoundingBox(50f, 50f, 50f, 50f)
        assertEquals(0f, bbox.width)
        assertEquals(0f, bbox.height)
        assertEquals(50f, bbox.centerX)
        assertEquals(50f, bbox.centerY)
    }

    @Test
    fun `BoundingBox with negative coordinates`() {
        val bbox = BoundingBox(-100f, -100f, -50f, -50f)
        assertEquals(50f, bbox.width)
        assertEquals(50f, bbox.height)
        assertEquals(-75f, bbox.centerX)
        assertEquals(-75f, bbox.centerY)
    }

    @Test
    fun `BoundingBox with very large coordinates`() {
        val bbox = BoundingBox(0f, 0f, 10000f, 10000f)
        assertEquals(10000f, bbox.width)
        assertEquals(10000f, bbox.height)
        assertEquals(5000f, bbox.centerX)
        assertEquals(5000f, bbox.centerY)
    }

    @Test
    fun `BoundingBox computed properties recalculation`() {
        val bbox = BoundingBox(0f, 0f, 100f, 100f)

        // Call computed properties multiple times to ensure consistency
        assertEquals(100f, bbox.width)
        assertEquals(100f, bbox.width)
        assertEquals(100f, bbox.height)
        assertEquals(100f, bbox.height)
        assertEquals(50f, bbox.centerX)
        assertEquals(50f, bbox.centerY)
    }

    // ========== HairAnalysis Value Range Tests ==========
    @Test
    fun `HairAnalysis with negative values`() {
        val analysis = HairAnalysis(
            hairType = HairType.STRAIGHT,
            hairLength = HairLength.MEDIUM,
            textureScore = -0.5f,
            volumeEstimate = -0.3f,
            confidence = -0.1f
        )

        assertEquals(-0.5f, analysis.textureScore)
        assertEquals(-0.3f, analysis.volumeEstimate)
        assertEquals(-0.1f, analysis.confidence)
    }

    @Test
    fun `HairAnalysis with values greater than 1`() {
        val analysis = HairAnalysis(
            hairType = HairType.CURLY,
            hairLength = HairLength.LONG,
            textureScore = 1.5f,
            volumeEstimate = 2.0f,
            confidence = 1.8f
        )

        assertEquals(1.5f, analysis.textureScore)
        assertEquals(2.0f, analysis.volumeEstimate)
        assertEquals(1.8f, analysis.confidence)
    }

    @Test
    fun `HairAnalysis with minimum float values`() {
        val analysis = HairAnalysis(
            hairType = HairType.UNKNOWN,
            hairLength = HairLength.UNKNOWN,
            textureScore = Float.MIN_VALUE,
            volumeEstimate = Float.MIN_VALUE,
            confidence = Float.MIN_VALUE
        )

        assertEquals(Float.MIN_VALUE, analysis.textureScore)
        assertEquals(Float.MIN_VALUE, analysis.volumeEstimate)
        assertEquals(Float.MIN_VALUE, analysis.confidence)
    }

    @Test
    fun `HairAnalysis with maximum float values`() {
        val analysis = HairAnalysis(
            hairType = HairType.COILY,
            hairLength = HairLength.EXTRA_LONG,
            textureScore = Float.MAX_VALUE,
            volumeEstimate = Float.MAX_VALUE,
            confidence = Float.MAX_VALUE
        )

        assertEquals(Float.MAX_VALUE, analysis.textureScore)
        assertEquals(Float.MAX_VALUE, analysis.volumeEstimate)
        assertEquals(Float.MAX_VALUE, analysis.confidence)
    }

    // ========== ColorInfo Value Range Tests ==========
    @Test
    fun `ColorInfo with boundary brightness values`() {
        val colorInfo1 = ColorInfo(
            primaryColor = Color.White,
            brightness = 0f,
            saturation = 0.5f
        )
        assertEquals(0f, colorInfo1.brightness)

        val colorInfo2 = ColorInfo(
            primaryColor = Color.Black,
            brightness = 1f,
            saturation = 0.5f
        )
        assertEquals(1f, colorInfo2.brightness)
    }

    @Test
    fun `ColorInfo with boundary saturation values`() {
        val colorInfo1 = ColorInfo(
            primaryColor = Color.Gray,
            brightness = 0.5f,
            saturation = 0f
        )
        assertEquals(0f, colorInfo1.saturation)

        val colorInfo2 = ColorInfo(
            primaryColor = Color.Red,
            brightness = 0.5f,
            saturation = 1f
        )
        assertEquals(1f, colorInfo2.saturation)
    }

    @Test
    fun `ColorInfo with extreme brightness values`() {
        val colorInfo1 = ColorInfo(
            primaryColor = Color.White,
            brightness = -1f,
            saturation = 0.5f
        )
        assertEquals(-1f, colorInfo1.brightness)

        val colorInfo2 = ColorInfo(
            primaryColor = Color.Black,
            brightness = 2f,
            saturation = 0.5f
        )
        assertEquals(2f, colorInfo2.brightness)
    }

    // ========== ColorAdjustments Value Range Tests ==========
    @Test
    fun `ColorAdjustments with minimum values`() {
        val adjustments = ColorAdjustments(
            brightness = -1f,
            saturation = -1f,
            hue = -180f
        )

        assertEquals(-1f, adjustments.brightness)
        assertEquals(-1f, adjustments.saturation)
        assertEquals(-180f, adjustments.hue)
    }

    @Test
    fun `ColorAdjustments with maximum values`() {
        val adjustments = ColorAdjustments(
            brightness = 1f,
            saturation = 1f,
            hue = 180f
        )

        assertEquals(1f, adjustments.brightness)
        assertEquals(1f, adjustments.saturation)
        assertEquals(180f, adjustments.hue)
    }

    @Test
    fun `ColorAdjustments with extreme values`() {
        val adjustments = ColorAdjustments(
            brightness = -2f,
            saturation = 2f,
            hue = 360f
        )

        assertEquals(-2f, adjustments.brightness)
        assertEquals(2f, adjustments.saturation)
        assertEquals(360f, adjustments.hue)
    }

    // ========== HairColor Edge Cases ==========
    @Test
    fun `HairColor with empty highlights list`() {
        val hairColor = HairColor(
            id = "test",
            name = "Test Color",
            baseColor = Color.Black,
            highlights = emptyList()
        )

        assertTrue(hairColor.highlights.isEmpty())
        assertEquals(0, hairColor.highlights.size)
    }

    @Test
    fun `HairColor with multiple highlights`() {
        val highlights = listOf(
            Color.Red,
            Color.Yellow,
            Color.Blue,
            Color.Green,
            Color.Cyan
        )
        val hairColor = HairColor(
            id = "test",
            name = "Rainbow",
            baseColor = Color.White,
            highlights = highlights
        )

        assertEquals(5, hairColor.highlights.size)
        assertEquals(highlights, hairColor.highlights)
    }

    @Test
    fun `HairColor gradient without style`() {
        val hairColor = HairColor(
            id = "test",
            name = "Test",
            baseColor = Color.Black,
            isGradient = true,
            gradientStyle = null
        )

        assertTrue(hairColor.isGradient)
        assertNull(hairColor.gradientStyle)
    }

    @Test
    fun `HairColor non-gradient with style`() {
        val hairColor = HairColor(
            id = "test",
            name = "Test",
            baseColor = Color.Black,
            isGradient = false,
            gradientStyle = GradientStyle.OMBRE
        )

        assertFalse(hairColor.isGradient)
        assertNotNull(hairColor.gradientStyle)
    }

    // ========== FaceLandmarksResult Edge Cases ==========
    @Test
    fun `FaceLandmarksResult with empty keyPoints`() {
        val result = FaceLandmarksResult(
            boundingBox = BoundingBox(0f, 0f, 100f, 100f),
            keyPoints = emptyMap(),
            confidence = 0.8f
        )

        assertTrue(result.keyPoints.isEmpty())
        assertEquals(0, result.keyPoints.size)
    }

    @Test
    fun `FaceLandmarksResult with all landmark types`() {
        val allLandmarks = LandmarkType.values().associateWith {
            PointF(it.ordinal * 10f, it.ordinal * 10f)
        }

        val result = FaceLandmarksResult(
            boundingBox = BoundingBox(0f, 0f, 150f, 150f),
            keyPoints = allLandmarks,
            confidence = 0.95f
        )

        assertEquals(15, result.keyPoints.size)
        assertTrue(result.keyPoints.containsKey(LandmarkType.LEFT_EYE))
        assertTrue(result.keyPoints.containsKey(LandmarkType.HAIR_RIGHT))
    }

    @Test
    fun `FaceLandmarksResult with zero confidence`() {
        val result = FaceLandmarksResult(
            boundingBox = BoundingBox(0f, 0f, 100f, 100f),
            keyPoints = mapOf(LandmarkType.NOSE_TIP to PointF(50f, 50f)),
            confidence = 0f
        )

        assertEquals(0f, result.confidence)
    }

    @Test
    fun `FaceLandmarksResult with confidence greater than 1`() {
        val result = FaceLandmarksResult(
            boundingBox = BoundingBox(0f, 0f, 100f, 100f),
            keyPoints = mapOf(LandmarkType.MOUTH_CENTER to PointF(50f, 70f)),
            confidence = 1.5f
        )

        assertEquals(1.5f, result.confidence)
    }

    @Test
    fun `FaceLandmarksResult with negative confidence`() {
        val result = FaceLandmarksResult(
            boundingBox = BoundingBox(0f, 0f, 100f, 100f),
            keyPoints = mapOf(LandmarkType.CHIN to PointF(50f, 90f)),
            confidence = -0.5f
        )

        assertEquals(-0.5f, result.confidence)
    }

    // ========== HairAnalysisResult Edge Cases ==========
    @Test
    fun `HairAnalysisResult with null segmentation mask`() {
        val result = HairAnalysisResult(
            segmentationMask = null,
            hairAnalysis = HairAnalysis(
                hairType = HairType.STRAIGHT,
                hairLength = HairLength.MEDIUM,
                textureScore = 0.7f,
                volumeEstimate = 0.6f,
                confidence = 0.8f
            ),
            hairColor = ColorInfo(Color.Black, brightness = 0.5f, saturation = 0.5f),
            faceLandmarks = null,
            processingTimeMs = 150L
        )

        assertNull(result.segmentationMask)
        assertNull(result.faceLandmarks)
    }

    @Test
    fun `HairAnalysisResult with zero processing time`() {
        val result = HairAnalysisResult(
            segmentationMask = null,
            hairAnalysis = HairAnalysis(
                hairType = HairType.WAVY,
                hairLength = HairLength.SHORT,
                textureScore = 0.6f,
                volumeEstimate = 0.5f,
                confidence = 0.7f
            ),
            hairColor = ColorInfo(Color.Red, brightness = 0.6f, saturation = 0.6f),
            faceLandmarks = null,
            processingTimeMs = 0L
        )

        assertEquals(0L, result.processingTimeMs)
    }

    @Test
    fun `HairAnalysisResult with very large processing time`() {
        val result = HairAnalysisResult(
            segmentationMask = null,
            hairAnalysis = HairAnalysis(
                hairType = HairType.CURLY,
                hairLength = HairLength.LONG,
                textureScore = 0.8f,
                volumeEstimate = 0.7f,
                confidence = 0.9f
            ),
            hairColor = ColorInfo(Color.Blue, brightness = 0.7f, saturation = 0.7f),
            faceLandmarks = null,
            processingTimeMs = Long.MAX_VALUE
        )

        assertEquals(Long.MAX_VALUE, result.processingTimeMs)
    }

    @Test
    fun `HairAnalysisResult isConfident at boundary`() {
        val result = HairAnalysisResult(
            segmentationMask = null,
            hairAnalysis = HairAnalysis(
                hairType = HairType.STRAIGHT,
                hairLength = HairLength.MEDIUM,
                textureScore = 0.5f,
                volumeEstimate = 0.5f,
                confidence = 0.5001f  // Just above threshold
            ),
            hairColor = ColorInfo(Color.Green, brightness = 0.5f, saturation = 0.5f),
            faceLandmarks = null,
            processingTimeMs = 100L
        )

        assertTrue(result.isConfident())
    }

    @Test
    fun `HairAnalysisResult hasFaceLandmarks at boundary`() {
        val result = HairAnalysisResult(
            segmentationMask = null,
            hairAnalysis = HairAnalysis(
                hairType = HairType.COILY,
                hairLength = HairLength.EXTRA_LONG,
                textureScore = 0.9f,
                volumeEstimate = 0.8f,
                confidence = 0.9f
            ),
            hairColor = ColorInfo(Color.Yellow, brightness = 0.8f, saturation = 0.8f),
            faceLandmarks = FaceLandmarksResult(
                boundingBox = BoundingBox(0f, 0f, 100f, 100f),
                keyPoints = emptyMap(),
                confidence = 0.5001f  // Just above threshold
            ),
            processingTimeMs = 100L
        )

        assertTrue(result.hasFaceLandmarks())
    }

    // ========== Enum ValueOf Edge Cases ==========
    @Test(expected = IllegalArgumentException::class)
    fun `HairType valueOf with invalid string`() {
        HairType.valueOf("INVALID_TYPE")
    }

    @Test(expected = IllegalArgumentException::class)
    fun `HairLength valueOf with invalid string`() {
        HairLength.valueOf("INVALID_LENGTH")
    }

    @Test(expected = IllegalArgumentException::class)
    fun `GradientStyle valueOf with invalid string`() {
        GradientStyle.valueOf("INVALID_STYLE")
    }

    @Test(expected = IllegalArgumentException::class)
    fun `LandmarkType valueOf with invalid string`() {
        LandmarkType.valueOf("INVALID_LANDMARK")
    }

    @Test(expected = IllegalArgumentException::class)
    fun `LengthPreset valueOf with invalid string`() {
        LengthPreset.valueOf("INVALID_PRESET")
    }

    @Test(expected = IllegalArgumentException::class)
    fun `BangStyle valueOf with invalid string`() {
        BangStyle.valueOf("INVALID_BANG")
    }

    @Test(expected = IllegalArgumentException::class)
    fun `HairAccessory valueOf with invalid string`() {
        HairAccessory.valueOf("INVALID_ACCESSORY")
    }

    // ========== HairStyleSelection When Expression Tests ==========
    @Test
    fun `HairStyleSelection when expression with Length`() {
        val selection = HairStyleSelection.Length(LengthPreset.LONG)

        val result = when (selection) {
            is HairStyleSelection.Length -> "Length: ${selection.preset.displayName}"
            is HairStyleSelection.Bangs -> "Bangs: ${selection.style.displayName}"
            is HairStyleSelection.Accessory -> "Accessory: ${selection.accessory.displayName}"
        }

        assertEquals("Length: Long", result)
    }

    @Test
    fun `HairStyleSelection when expression with Bangs`() {
        val selection = HairStyleSelection.Bangs(BangStyle.CURTAIN)

        val result = when (selection) {
            is HairStyleSelection.Length -> "Length: ${selection.preset.displayName}"
            is HairStyleSelection.Bangs -> "Bangs: ${selection.style.displayName}"
            is HairStyleSelection.Accessory -> "Accessory: ${selection.accessory.displayName}"
        }

        assertEquals("Bangs: Curtain Bangs", result)
    }

    @Test
    fun `HairStyleSelection when expression with Accessory`() {
        val selection = HairStyleSelection.Accessory(HairAccessory.TIARA)

        val result = when (selection) {
            is HairStyleSelection.Length -> "Length: ${selection.preset.displayName}"
            is HairStyleSelection.Bangs -> "Bangs: ${selection.style.displayName}"
            is HairStyleSelection.Accessory -> "Accessory: ${selection.accessory.displayName}"
        }

        assertEquals("Accessory: Tiara", result)
    }

    // ========== Sealed Class Properties Tests ==========
    @Test
    fun `LengthPreset all display names are non-empty`() {
        LengthPreset.values().forEach { preset ->
            assertTrue(preset.displayName.isNotEmpty())
            assertTrue(preset.description.isNotEmpty())
        }
    }

    @Test
    fun `BangStyle all display names are unique`() {
        val displayNames = BangStyle.values().map { it.displayName }
        val uniqueNames = displayNames.toSet()
        assertEquals(displayNames.size, uniqueNames.size)
    }

    @Test
    fun `HairAccessory all display names are unique`() {
        val displayNames = HairAccessory.values().map { it.displayName }
        val uniqueNames = displayNames.toSet()
        assertEquals(displayNames.size, uniqueNames.size)
    }

    @Test
    fun `LandmarkType contains all expected landmarks`() {
        val expectedLandmarks = setOf(
            LandmarkType.LEFT_EYE,
            LandmarkType.RIGHT_EYE,
            LandmarkType.NOSE_TIP,
            LandmarkType.MOUTH_CENTER,
            LandmarkType.LEFT_EAR,
            LandmarkType.RIGHT_EAR,
            LandmarkType.FOREHEAD,
            LandmarkType.CHIN,
            LandmarkType.LEFT_TEMPLE,
            LandmarkType.RIGHT_TEMPLE,
            LandmarkType.FACE_OVAL_TOP,
            LandmarkType.FACE_OVAL_BOTTOM,
            LandmarkType.HAIR_TOP,
            LandmarkType.HAIR_LEFT,
            LandmarkType.HAIR_RIGHT
        )

        val allLandmarks = LandmarkType.values().toSet()
        assertEquals(expectedLandmarks, allLandmarks)
    }

    // ========== Data Class Component Functions ==========
    @Test
    fun `HairAnalysis component1 through component5`() {
        val analysis = HairAnalysis(
            hairType = HairType.STRAIGHT,
            hairLength = HairLength.MEDIUM,
            textureScore = 0.7f,
            volumeEstimate = 0.6f,
            confidence = 0.8f
        )

        assertEquals(HairType.STRAIGHT, analysis.component1())
        assertEquals(HairLength.MEDIUM, analysis.component2())
        assertEquals(0.7f, analysis.component3())
        assertEquals(0.6f, analysis.component4())
        assertEquals(0.8f, analysis.component5())
    }

    @Test
    fun `ColorInfo component1 through component4`() {
        val colorInfo = ColorInfo(
            primaryColor = Color.Red,
            secondaryColor = Color.Blue,
            brightness = 0.7f,
            saturation = 0.8f
        )

        assertEquals(Color.Red, colorInfo.component1())
        assertEquals(Color.Blue, colorInfo.component2())
        assertEquals(0.7f, colorInfo.component3())
        assertEquals(0.8f, colorInfo.component4())
    }

    @Test
    fun `BoundingBox component1 through component4`() {
        val bbox = BoundingBox(10f, 20f, 100f, 200f)

        assertEquals(10f, bbox.component1())
        assertEquals(20f, bbox.component2())
        assertEquals(100f, bbox.component3())
        assertEquals(200f, bbox.component4())
    }

    // ========== Destructuring Tests ==========
    @Test
    fun `HairAnalysis destructuring`() {
        val analysis = HairAnalysis(
            hairType = HairType.CURLY,
            hairLength = HairLength.LONG,
            textureScore = 0.8f,
            volumeEstimate = 0.7f,
            confidence = 0.9f
        )

        val (type, length, texture, volume, conf) = analysis

        assertEquals(HairType.CURLY, type)
        assertEquals(HairLength.LONG, length)
        assertEquals(0.8f, texture)
        assertEquals(0.7f, volume)
        assertEquals(0.9f, conf)
    }

    @Test
    fun `ColorInfo destructuring with secondary color`() {
        val colorInfo = ColorInfo(
            primaryColor = Color.Yellow,
            secondaryColor = Color.Magenta,
            brightness = 0.9f,
            saturation = 0.7f
        )

        val (primary, secondary, brightness, saturation) = colorInfo

        assertEquals(Color.Yellow, primary)
        assertEquals(Color.Magenta, secondary)
        assertEquals(0.9f, brightness)
        assertEquals(0.7f, saturation)
    }

    @Test
    fun `BoundingBox destructuring`() {
        val bbox = BoundingBox(5f, 15f, 95f, 185f)

        val (left, top, right, bottom) = bbox

        assertEquals(5f, left)
        assertEquals(15f, top)
        assertEquals(95f, right)
        assertEquals(185f, bottom)
    }

    // ========== Special Float Values ==========
    @Test
    fun `HairAnalysis with NaN values`() {
        val analysis = HairAnalysis(
            hairType = HairType.UNKNOWN,
            hairLength = HairLength.UNKNOWN,
            textureScore = Float.NaN,
            volumeEstimate = Float.NaN,
            confidence = Float.NaN
        )

        assertTrue(analysis.textureScore.isNaN())
        assertTrue(analysis.volumeEstimate.isNaN())
        assertTrue(analysis.confidence.isNaN())
    }

    @Test
    fun `HairAnalysis with positive infinity`() {
        val analysis = HairAnalysis(
            hairType = HairType.STRAIGHT,
            hairLength = HairLength.SHORT,
            textureScore = Float.POSITIVE_INFINITY,
            volumeEstimate = Float.POSITIVE_INFINITY,
            confidence = Float.POSITIVE_INFINITY
        )

        assertTrue(analysis.textureScore.isInfinite())
        assertTrue(analysis.volumeEstimate.isInfinite())
        assertTrue(analysis.confidence.isInfinite())
    }

    @Test
    fun `HairAnalysis with negative infinity`() {
        val analysis = HairAnalysis(
            hairType = HairType.WAVY,
            hairLength = HairLength.MEDIUM,
            textureScore = Float.NEGATIVE_INFINITY,
            volumeEstimate = Float.NEGATIVE_INFINITY,
            confidence = Float.NEGATIVE_INFINITY
        )

        assertTrue(analysis.textureScore.isInfinite())
        assertTrue(analysis.volumeEstimate.isInfinite())
        assertTrue(analysis.confidence.isInfinite())
    }
}
