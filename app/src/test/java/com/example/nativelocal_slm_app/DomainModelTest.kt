package com.example.nativelocal_slm_app

import android.graphics.PointF
import androidx.compose.ui.graphics.Color
import com.example.nativelocal_slm_app.domain.model.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Comprehensive tests for all domain models.
 * Tests data classes, enums, and their properties/methods.
 */
@RunWith(RobolectricTestRunner::class)
class DomainModelTest {

    // ========== HairType Tests ==========
    @Test
    fun `test HairType enum values`() {
        val types = HairType.values()
        assertEquals(5, types.size)
        assertTrue(types.contains(HairType.STRAIGHT))
        assertTrue(types.contains(HairType.WAVY))
        assertTrue(types.contains(HairType.CURLY))
        assertTrue(types.contains(HairType.COILY))
        assertTrue(types.contains(HairType.UNKNOWN))

        // Call additional enum methods to increase coverage
        assertEquals("STRAIGHT", HairType.STRAIGHT.name)
        assertEquals(0, HairType.STRAIGHT.ordinal)
        assertEquals(HairType.STRAIGHT, HairType.valueOf("STRAIGHT"))
    }

    @Test
    fun `test HairLength enum values`() {
        val lengths = HairLength.values()
        assertEquals(5, lengths.size)
        assertTrue(lengths.contains(HairLength.SHORT))
        assertTrue(lengths.contains(HairLength.MEDIUM))
        assertTrue(lengths.contains(HairLength.LONG))
        assertTrue(lengths.contains(HairLength.EXTRA_LONG))
        assertTrue(lengths.contains(HairLength.UNKNOWN))

        // Call additional enum methods to increase coverage
        assertEquals("SHORT", HairLength.SHORT.name)
        assertEquals(0, HairLength.SHORT.ordinal)
        assertEquals(HairLength.SHORT, HairLength.valueOf("SHORT"))
    }

    // ========== HairAnalysis Tests ==========
    @Test
    fun `test HairAnalysis data class creation`() {
        val analysis = HairAnalysis(
            hairType = HairType.STRAIGHT,
            hairLength = HairLength.MEDIUM,
            textureScore = 0.7f,
            volumeEstimate = 0.6f,
            confidence = 0.8f
        )

        assertEquals(HairType.STRAIGHT, analysis.hairType)
        assertEquals(HairLength.MEDIUM, analysis.hairLength)
        assertEquals(0.7f, analysis.textureScore)
        assertEquals(0.6f, analysis.volumeEstimate)
        assertEquals(0.8f, analysis.confidence)
    }

    @Test
    fun `test HairAnalysis with boundary values`() {
        val analysis1 = HairAnalysis(
            hairType = HairType.STRAIGHT,
            hairLength = HairLength.SHORT,
            textureScore = 0f,
            volumeEstimate = 0f,
            confidence = 0f
        )

        assertEquals(0f, analysis1.textureScore)
        assertEquals(0f, analysis1.volumeEstimate)
        assertEquals(0f, analysis1.confidence)

        val analysis2 = HairAnalysis(
            hairType = HairType.CURLY,
            hairLength = HairLength.LONG,
            textureScore = 1f,
            volumeEstimate = 1f,
            confidence = 1f
        )

        assertEquals(1f, analysis2.textureScore)
        assertEquals(1f, analysis2.volumeEstimate)
        assertEquals(1f, analysis2.confidence)
    }

    // ========== ColorInfo Tests ==========
    @Test
    fun `test ColorInfo creation without secondary color`() {
        val colorInfo = ColorInfo(
            primaryColor = Color.Black,
            brightness = 0.5f,
            saturation = 0.6f
        )

        assertEquals(Color.Black, colorInfo.primaryColor)
        assertEquals(0.5f, colorInfo.brightness)
        assertEquals(0.6f, colorInfo.saturation)
    }

    @Test
    fun `test ColorInfo creation with secondary color`() {
        val colorInfo = ColorInfo(
            primaryColor = Color.Red,
            secondaryColor = Color.Blue,
            brightness = 0.7f,
            saturation = 0.8f
        )

        assertEquals(Color.Red, colorInfo.primaryColor)
        assertEquals(Color.Blue, colorInfo.secondaryColor)
        assertEquals(0.7f, colorInfo.brightness)
        assertEquals(0.8f, colorInfo.saturation)
    }

    // ========== HairColor Tests ==========
    @Test
    fun `test HairColor creation without highlights`() {
        val hairColor = HairColor(
            id = "color_1",
            name = "Natural Black",
            baseColor = Color.Black
        )

        assertEquals("color_1", hairColor.id)
        assertEquals("Natural Black", hairColor.name)
        assertEquals(Color.Black, hairColor.baseColor)
        assertEquals(emptyList(), hairColor.highlights)
        assertFalse(hairColor.isGradient)
    }

    @Test
    fun `test HairColor creation with highlights`() {
        val highlights = listOf(Color.Red, Color.Yellow)
        val hairColor = HairColor(
            id = "color_2",
            name = "Auburn",
            baseColor = Color.Red,
            highlights = highlights
        )

        assertEquals(highlights, hairColor.highlights)
        assertEquals(2, hairColor.highlights.size)
    }

    @Test
    fun `test HairColor with gradient`() {
        val hairColor = HairColor(
            id = "color_3",
            name = "Ombre Blonde",
            baseColor = Color.DarkGray,
            isGradient = true,
            gradientStyle = GradientStyle.OMBRE
        )

        assertTrue(hairColor.isGradient)
        assertEquals(GradientStyle.OMBRE, hairColor.gradientStyle)
    }

    // ========== GradientStyle Tests ==========
    @Test
    fun `test GradientStyle enum values`() {
        val styles = GradientStyle.values()
        assertEquals(4, styles.size)
        assertTrue(styles.contains(GradientStyle.OMBRE))
        assertTrue(styles.contains(GradientStyle.BALAYAGE))
        assertTrue(styles.contains(GradientStyle.SOMBRÉ))
        assertTrue(styles.contains(GradientStyle.TWO_TONE))
    }

    // ========== ColorAdjustments Tests ==========
    @Test
    fun `test ColorAdjustments with default values`() {
        val adjustments = ColorAdjustments()

        assertEquals(0f, adjustments.brightness)
        assertEquals(0f, adjustments.saturation)
        assertEquals(0f, adjustments.hue)
    }

    @Test
    fun `test ColorAdjustments with custom values`() {
        val adjustments = ColorAdjustments(
            brightness = 0.5f,
            saturation = -0.3f,
            hue = 45f
        )

        assertEquals(0.5f, adjustments.brightness)
        assertEquals(-0.3f, adjustments.saturation)
        assertEquals(45f, adjustments.hue)
    }

    // ========== BoundingBox Tests ==========
    @Test
    fun `test BoundingBox creation`() {
        val bbox = BoundingBox(10f, 20f, 100f, 200f)

        assertEquals(10f, bbox.left)
        assertEquals(20f, bbox.top)
        assertEquals(100f, bbox.right)
        assertEquals(200f, bbox.bottom)
    }

    @Test
    fun `test BoundingBox computed width`() {
        val bbox = BoundingBox(10f, 20f, 100f, 200f)
        assertEquals(90f, bbox.width)
    }

    @Test
    fun `test BoundingBox computed height`() {
        val bbox = BoundingBox(10f, 20f, 100f, 200f)
        assertEquals(180f, bbox.height)
    }

    @Test
    fun `test BoundingBox computed center X`() {
        val bbox = BoundingBox(0f, 0f, 100f, 100f)
        assertEquals(50f, bbox.centerX)
    }

    @Test
    fun `test BoundingBox computed center Y`() {
        val bbox = BoundingBox(0f, 0f, 100f, 100f)
        assertEquals(50f, bbox.centerY)
    }

    @Test
    fun `test BoundingBox with asymmetric coordinates`() {
        val bbox = BoundingBox(10f, 30f, 90f, 170f)

        assertEquals(80f, bbox.width)
        assertEquals(140f, bbox.height)
        assertEquals(50f, bbox.centerX)
        assertEquals(100f, bbox.centerY)
    }

    // ========== LandmarkType Tests ==========
    @Test
    fun `test LandmarkType enum values`() {
        val landmarks = LandmarkType.values()
        assertEquals(15, landmarks.size)
        assertTrue(landmarks.contains(LandmarkType.LEFT_EYE))
        assertTrue(landmarks.contains(LandmarkType.RIGHT_EYE))
        assertTrue(landmarks.contains(LandmarkType.NOSE_TIP))
        assertTrue(landmarks.contains(LandmarkType.MOUTH_CENTER))
        assertTrue(landmarks.contains(LandmarkType.HAIR_TOP))
        assertTrue(landmarks.contains(LandmarkType.HAIR_LEFT))
        assertTrue(landmarks.contains(LandmarkType.HAIR_RIGHT))
    }

    // ========== FaceLandmarksResult Tests ==========
    @Test
    fun `test FaceLandmarksResult creation`() {
        val bbox = BoundingBox(10f, 10f, 100f, 100f)
        val keyPoints = mapOf(
            LandmarkType.LEFT_EYE to PointF(30f, 40f),
            LandmarkType.RIGHT_EYE to PointF(70f, 40f)
        )

        val result = FaceLandmarksResult(
            boundingBox = bbox,
            keyPoints = keyPoints,
            confidence = 0.9f
        )

        assertEquals(bbox, result.boundingBox)
        assertEquals(2, result.keyPoints.size)
        assertEquals(0.9f, result.confidence)
    }

    @Test
    fun `test FaceLandmarksResult with default timestamp`() {
        val beforeTime = System.currentTimeMillis()
        val result = FaceLandmarksResult(
            boundingBox = BoundingBox(0f, 0f, 100f, 100f),
            keyPoints = emptyMap(),
            confidence = 0.8f
        )
        val afterTime = System.currentTimeMillis()

        assertTrue(result.timestamp >= beforeTime)
        assertTrue(result.timestamp <= afterTime)
    }

    @Test
    fun `test FaceLandmarksResult with custom timestamp`() {
        val customTime = 123456789L
        val result = FaceLandmarksResult(
            boundingBox = BoundingBox(0f, 0f, 100f, 100f),
            keyPoints = emptyMap(),
            confidence = 0.8f,
            timestamp = customTime
        )

        assertEquals(customTime, result.timestamp)
    }

    // ========== HairAnalysisResult Tests ==========
    @Test
    fun `test HairAnalysisResult creation`() {
        val bitmap = android.graphics.Bitmap.createBitmap(100, 100, android.graphics.Bitmap.Config.ARGB_8888)
        val hairAnalysis = HairAnalysis(
            hairType = HairType.STRAIGHT,
            hairLength = HairLength.MEDIUM,
            textureScore = 0.7f,
            volumeEstimate = 0.6f,
            confidence = 0.8f
        )
        val colorInfo = ColorInfo(
            primaryColor = Color.Black,
            brightness = 0.5f,
            saturation = 0.5f
        )
        val faceLandmarks = FaceLandmarksResult(
            boundingBox = BoundingBox(10f, 10f, 90f, 90f),
            keyPoints = emptyMap(),
            confidence = 0.9f
        )

        val result = HairAnalysisResult(
            segmentationMask = bitmap,
            hairAnalysis = hairAnalysis,
            hairColor = colorInfo,
            faceLandmarks = faceLandmarks,
            processingTimeMs = 100L
        )

        assertNotNull(result.segmentationMask)
        assertEquals(hairAnalysis, result.hairAnalysis)
        assertEquals(colorInfo, result.hairColor)
        assertNotNull(result.faceLandmarks)
        assertEquals(100L, result.processingTimeMs)
    }

    @Test
    fun `test HairAnalysisResult isConfident with high confidence`() {
        val result = HairAnalysisResult(
            segmentationMask = null,
            hairAnalysis = HairAnalysis(
                hairType = HairType.STRAIGHT,
                hairLength = HairLength.MEDIUM,
                textureScore = 0.5f,
                volumeEstimate = 0.5f,
                confidence = 0.8f
            ),
            hairColor = ColorInfo(Color.Black, brightness = 0.5f, saturation = 0.5f),
            faceLandmarks = null,
            processingTimeMs = 100L
        )

        assertTrue(result.isConfident())
    }

    @Test
    fun `test HairAnalysisResult isConfident with low confidence`() {
        val result = HairAnalysisResult(
            segmentationMask = null,
            hairAnalysis = HairAnalysis(
                hairType = HairType.UNKNOWN,
                hairLength = HairLength.UNKNOWN,
                textureScore = 0f,
                volumeEstimate = 0f,
                confidence = 0.3f
            ),
            hairColor = ColorInfo(Color.Black, brightness = 0.5f, saturation = 0.5f),
            faceLandmarks = null,
            processingTimeMs = 100L
        )

        assertFalse(result.isConfident())
    }

    @Test
    fun `test HairAnalysisResult isConfident with threshold confidence`() {
        val result = HairAnalysisResult(
            segmentationMask = null,
            hairAnalysis = HairAnalysis(
                hairType = HairType.WAVY,
                hairLength = HairLength.SHORT,
                textureScore = 0.6f,
                volumeEstimate = 0.6f,
                confidence = 0.5f
            ),
            hairColor = ColorInfo(Color.Red, brightness = 0.6f, saturation = 0.6f),
            faceLandmarks = null,
            processingTimeMs = 100L
        )

        // 0.5f is not > 0.5f, so should be false
        assertFalse(result.isConfident())
    }

    @Test
    fun `test HairAnalysisResult hasFaceLandmarks with high confidence`() {
        val result = HairAnalysisResult(
            segmentationMask = null,
            hairAnalysis = HairAnalysis(
                hairType = HairType.STRAIGHT,
                hairLength = HairLength.MEDIUM,
                textureScore = 0.5f,
                volumeEstimate = 0.5f,
                confidence = 0.7f
            ),
            hairColor = ColorInfo(Color.Black, brightness = 0.5f, saturation = 0.5f),
            faceLandmarks = FaceLandmarksResult(
                boundingBox = BoundingBox(0f, 0f, 100f, 100f),
                keyPoints = emptyMap(),
                confidence = 0.8f
            ),
            processingTimeMs = 100L
        )

        assertTrue(result.hasFaceLandmarks())
    }

    @Test
    fun `test HairAnalysisResult hasFaceLandmarks with low confidence`() {
        val result = HairAnalysisResult(
            segmentationMask = null,
            hairAnalysis = HairAnalysis(
                hairType = HairType.CURLY,
                hairLength = HairLength.LONG,
                textureScore = 0.7f,
                volumeEstimate = 0.7f,
                confidence = 0.8f
            ),
            hairColor = ColorInfo(Color.Black, brightness = 0.5f, saturation = 0.5f),
            faceLandmarks = FaceLandmarksResult(
                boundingBox = BoundingBox(0f, 0f, 100f, 100f),
                keyPoints = emptyMap(),
                confidence = 0.3f
            ),
            processingTimeMs = 100L
        )

        assertFalse(result.hasFaceLandmarks())
    }

    @Test
    fun `test HairAnalysisResult hasFaceLandmarks without landmarks`() {
        val result = HairAnalysisResult(
            segmentationMask = null,
            hairAnalysis = HairAnalysis(
                hairType = HairType.STRAIGHT,
                hairLength = HairLength.SHORT,
                textureScore = 0.5f,
                volumeEstimate = 0.5f,
                confidence = 0.7f
            ),
            hairColor = ColorInfo(Color.Black, brightness = 0.5f, saturation = 0.5f),
            faceLandmarks = null,
            processingTimeMs = 100L
        )

        assertFalse(result.hasFaceLandmarks())
    }

    @Test
    fun `test HairAnalysisResult hasFaceLandmarks with threshold confidence`() {
        val result = HairAnalysisResult(
            segmentationMask = null,
            hairAnalysis = HairAnalysis(
                hairType = HairType.WAVY,
                hairLength = HairLength.MEDIUM,
                textureScore = 0.6f,
                volumeEstimate = 0.6f,
                confidence = 0.7f
            ),
            hairColor = ColorInfo(Color.Black, brightness = 0.5f, saturation = 0.5f),
            faceLandmarks = FaceLandmarksResult(
                boundingBox = BoundingBox(0f, 0f, 100f, 100f),
                keyPoints = emptyMap(),
                confidence = 0.5f
            ),
            processingTimeMs = 100L
        )

        // 0.5f is not > 0.5f, so should be false
        assertFalse(result.hasFaceLandmarks())
    }

    // ========== HairStyle Tests ==========
    @Test
    fun `test LengthPreset enum values`() {
        val presets = LengthPreset.values()
        assertEquals(5, presets.size)
        assertTrue(presets.contains(LengthPreset.SHORT))
        assertTrue(presets.contains(LengthPreset.SHOULDER))
        assertTrue(presets.contains(LengthPreset.MEDIUM))
        assertTrue(presets.contains(LengthPreset.LONG))
        assertTrue(presets.contains(LengthPreset.EXTRA_LONG))
    }

    @Test
    fun `test LengthPreset display names`() {
        assertEquals("Short", LengthPreset.SHORT.displayName)
        assertEquals("Shoulder Length", LengthPreset.SHOULDER.displayName)
        assertEquals("Medium", LengthPreset.MEDIUM.displayName)
        assertEquals("Long", LengthPreset.LONG.displayName)
        assertEquals("Extra Long", LengthPreset.EXTRA_LONG.displayName)
    }

    @Test
    fun `test BangStyle enum values`() {
        val styles = BangStyle.values()
        assertEquals(7, styles.size)
        assertTrue(styles.contains(BangStyle.NONE))
        assertTrue(styles.contains(BangStyle.STRAIGHT))
        assertTrue(styles.contains(BangStyle.SIDE_SWEEP))
        assertTrue(styles.contains(BangStyle.CURTAIN))
        assertTrue(styles.contains(BangStyle.BLUNT))
        assertTrue(styles.contains(BangStyle.WISPY))
        assertTrue(styles.contains(BangStyle.V_SHAPED))
    }

    @Test
    fun `test HairAccessory enum values`() {
        val accessories = HairAccessory.values()
        assertEquals(7, accessories.size)
        assertTrue(accessories.contains(HairAccessory.NONE))
        assertTrue(accessories.contains(HairAccessory.HEADBAND))
        assertTrue(accessories.contains(HairAccessory.FLOWER_CROWN))
        assertTrue(accessories.contains(HairAccessory.RIBBON))
        assertTrue(accessories.contains(HairAccessory.HAIR_PINS))
        assertTrue(accessories.contains(HairAccessory.TIARA))
        assertTrue(accessories.contains(HairAccessory.HAT))
    }

    @Test
    fun `test HairStyleSelection sealed hierarchy`() {
        val lengthSelection = HairStyleSelection.Length(LengthPreset.MEDIUM)
        assertTrue(lengthSelection is HairStyleSelection.Length)
        assertEquals(LengthPreset.MEDIUM, lengthSelection.preset)

        val accessorySelection = HairStyleSelection.Accessory(HairAccessory.HEADBAND)
        assertTrue(accessorySelection is HairStyleSelection.Accessory)
        assertEquals(HairAccessory.HEADBAND, accessorySelection.accessory)

        val bangsSelection = HairStyleSelection.Bangs(BangStyle.CURTAIN)
        assertTrue(bangsSelection is HairStyleSelection.Bangs)
        assertEquals(BangStyle.CURTAIN, bangsSelection.style)
    }

    // ========== Data Class Methods Coverage ==========
    @Test
    fun `test HairAnalysis toString equals hashCode copy`() {
        val analysis1 = HairAnalysis(
            hairType = HairType.STRAIGHT,
            hairLength = HairLength.MEDIUM,
            textureScore = 0.7f,
            volumeEstimate = 0.6f,
            confidence = 0.8f
        )

        // Test toString()
        val str = analysis1.toString()
        assertTrue(str.contains("HairAnalysis"))
        assertTrue(str.contains("STRAIGHT"))

        // Test equals()
        val analysis2 = HairAnalysis(
            hairType = HairType.STRAIGHT,
            hairLength = HairLength.MEDIUM,
            textureScore = 0.7f,
            volumeEstimate = 0.6f,
            confidence = 0.8f
        )
        assertEquals(analysis1, analysis2)
        assertEquals(analysis1.hashCode(), analysis2.hashCode())

        // Test copy()
        val analysis3 = analysis1.copy(confidence = 0.9f)
        assertEquals(0.7f, analysis3.textureScore)
        assertEquals(0.9f, analysis3.confidence)
        assert(analysis1 != analysis3)
    }

    @Test
    fun `test ColorInfo toString equals hashCode copy`() {
        val colorInfo1 = ColorInfo(
            primaryColor = Color.Red,
            secondaryColor = Color.Blue,
            brightness = 0.7f,
            saturation = 0.8f
        )

        // Test toString()
        val str = colorInfo1.toString()
        assertTrue(str.contains("ColorInfo"))

        // Test equals()
        val colorInfo2 = ColorInfo(
            primaryColor = Color.Red,
            secondaryColor = Color.Blue,
            brightness = 0.7f,
            saturation = 0.8f
        )
        assertEquals(colorInfo1, colorInfo2)
        assertEquals(colorInfo1.hashCode(), colorInfo2.hashCode())

        // Test copy()
        val colorInfo3 = colorInfo1.copy(brightness = 0.5f)
        assertEquals(Color.Red, colorInfo3.primaryColor)
        assertEquals(0.5f, colorInfo3.brightness)
    }

    @Test
    fun `test HairColor toString equals hashCode copy`() {
        val hairColor1 = HairColor(
            id = "color_1",
            name = "Test Color",
            baseColor = Color.Black,
            highlights = listOf(Color.Red, Color.Yellow),
            isGradient = true,
            gradientStyle = GradientStyle.OMBRE
        )

        // Test toString()
        val str = hairColor1.toString()
        assertTrue(str.contains("HairColor"))

        // Test equals()
        val hairColor2 = HairColor(
            id = "color_1",
            name = "Test Color",
            baseColor = Color.Black,
            highlights = listOf(Color.Red, Color.Yellow),
            isGradient = true,
            gradientStyle = GradientStyle.OMBRE
        )
        assertEquals(hairColor1, hairColor2)
        assertEquals(hairColor1.hashCode(), hairColor2.hashCode())

        // Test copy()
        val hairColor3 = hairColor1.copy(name = "Modified")
        assertEquals("color_1", hairColor3.id)
        assertEquals("Modified", hairColor3.name)
    }

    @Test
    fun `test BoundingBox toString equals hashCode`() {
        val bbox1 = BoundingBox(10f, 20f, 100f, 200f)

        // Test toString()
        val str = bbox1.toString()
        assertTrue(str.contains("BoundingBox"))

        // Test computed properties (already tested but call explicitly)
        assertEquals(90f, bbox1.width)
        assertEquals(180f, bbox1.height)
        assertEquals(55f, bbox1.centerX)
        assertEquals(110f, bbox1.centerY)

        // Test equals()
        val bbox2 = BoundingBox(10f, 20f, 100f, 200f)
        assertEquals(bbox1, bbox2)
        assertEquals(bbox1.hashCode(), bbox2.hashCode())

        // Test inequality
        val bbox3 = BoundingBox(10f, 20f, 90f, 200f)
        assert(bbox1 != bbox3)
    }

    @Test
    fun `test FaceLandmarksResult toString equals hashCode`() {
        val keyPoints = mapOf(
            LandmarkType.LEFT_EYE to PointF(30f, 40f),
            LandmarkType.RIGHT_EYE to PointF(70f, 40f)
        )
        val result1 = FaceLandmarksResult(
            boundingBox = BoundingBox(10f, 10f, 100f, 100f),
            keyPoints = keyPoints,
            confidence = 0.9f,
            timestamp = 123456L
        )

        // Test toString()
        val str = result1.toString()
        assertTrue(str.contains("FaceLandmarksResult"))

        // Test equals()
        val result2 = FaceLandmarksResult(
            boundingBox = BoundingBox(10f, 10f, 100f, 100f),
            keyPoints = keyPoints,
            confidence = 0.9f,
            timestamp = 123456L
        )
        assertEquals(result1, result2)
        assertEquals(result1.hashCode(), result2.hashCode())
    }

    @Test
    fun `test HairAnalysisResult toString equals hashCode`() {
        val bitmap = android.graphics.Bitmap.createBitmap(100, 100, android.graphics.Bitmap.Config.ARGB_8888)
        val hairAnalysis = HairAnalysis(
            hairType = HairType.STRAIGHT,
            hairLength = HairLength.MEDIUM,
            textureScore = 0.7f,
            volumeEstimate = 0.6f,
            confidence = 0.8f
        )
        val colorInfo = ColorInfo(
            primaryColor = Color.Black,
            brightness = 0.5f,
            saturation = 0.5f
        )
        val faceLandmarks = FaceLandmarksResult(
            boundingBox = BoundingBox(10f, 10f, 90f, 90f),
            keyPoints = emptyMap(),
            confidence = 0.9f
        )

        val result1 = HairAnalysisResult(
            segmentationMask = bitmap,
            hairAnalysis = hairAnalysis,
            hairColor = colorInfo,
            faceLandmarks = faceLandmarks,
            processingTimeMs = 100L
        )

        // Test toString()
        val str = result1.toString()
        assertTrue(str.contains("HairAnalysisResult"))

        // Test equals()
        val result2 = HairAnalysisResult(
            segmentationMask = bitmap,
            hairAnalysis = hairAnalysis,
            hairColor = colorInfo,
            faceLandmarks = faceLandmarks,
            processingTimeMs = 100L
        )
        assertEquals(result1, result2)
        assertEquals(result1.hashCode(), result2.hashCode())

        bitmap.recycle()
    }

    @Test
    fun `test ColorAdjustments toString equals hashCode copy`() {
        val adj1 = ColorAdjustments(
            brightness = 0.5f,
            saturation = -0.3f,
            hue = 45f
        )

        // Test toString()
        val str = adj1.toString()
        assertTrue(str.contains("ColorAdjustments"))

        // Test equals()
        val adj2 = ColorAdjustments(
            brightness = 0.5f,
            saturation = -0.3f,
            hue = 45f
        )
        assertEquals(adj1, adj2)
        assertEquals(adj1.hashCode(), adj2.hashCode())

        // Test copy()
        val adj3 = adj1.copy(brightness = 0.8f)
        assertEquals(0.8f, adj3.brightness)
        assertEquals(-0.3f, adj3.saturation)
    }

    @Test
    fun `test GradientStyle enum methods`() {
        val styles = GradientStyle.values()
        assertEquals(4, styles.size)

        // Test additional enum methods
        assertEquals("OMBRE", GradientStyle.OMBRE.name)
        assertEquals(0, GradientStyle.OMBRE.ordinal)
        assertEquals(GradientStyle.OMBRE, GradientStyle.valueOf("OMBRE"))
    }

    @Test
    fun `test LandmarkType enum methods`() {
        val landmarks = LandmarkType.values()
        assertEquals(15, landmarks.size)

        // Test additional enum methods
        assertEquals("LEFT_EYE", LandmarkType.LEFT_EYE.name)
        assertEquals(0, LandmarkType.LEFT_EYE.ordinal)
        assertEquals(LandmarkType.LEFT_EYE, LandmarkType.valueOf("LEFT_EYE"))
    }

    @Test
    fun `test LengthPreset enum methods and properties`() {
        val presets = LengthPreset.values()
        assertEquals(5, presets.size)

        // Test enum methods
        assertEquals("SHORT", LengthPreset.SHORT.name)
        assertEquals(0, LengthPreset.SHORT.ordinal)
        assertEquals(LengthPreset.SHORT, LengthPreset.valueOf("SHORT"))

        // Test properties
        assertEquals("Short", LengthPreset.SHORT.displayName)
        assertEquals("Above chin length", LengthPreset.SHORT.description)
        assertEquals("Shoulder Length", LengthPreset.SHOULDER.displayName)
    }

    @Test
    fun `test BangStyle enum methods and properties`() {
        val styles = BangStyle.values()
        assertEquals(7, styles.size)

        // Test enum methods
        assertEquals("NONE", BangStyle.NONE.name)
        assertEquals("Straight Bangs", BangStyle.STRAIGHT.displayName)
        assertEquals(BangStyle.CURTAIN, BangStyle.valueOf("CURTAIN"))
    }

    @Test
    fun `test HairAccessory enum methods and properties`() {
        val accessories = HairAccessory.values()
        assertEquals(7, accessories.size)

        // Test enum methods
        assertEquals("NONE", HairAccessory.NONE.name)
        assertEquals("Headband", HairAccessory.HEADBAND.displayName)
        assertEquals(HairAccessory.TIARA, HairAccessory.valueOf("TIARA"))
    }

    @Test
    fun `test HairStyleSelection sealed class toString equals`() {
        val lengthSelection = HairStyleSelection.Length(LengthPreset.MEDIUM)
        val accessorySelection = HairStyleSelection.Accessory(HairAccessory.HEADBAND)
        val bangsSelection = HairStyleSelection.Bangs(BangStyle.CURTAIN)

        // Test toString()
        assertTrue(lengthSelection.toString().contains("Length"))
        assertTrue(accessorySelection.toString().contains("Accessory"))
        assertTrue(bangsSelection.toString().contains("Bangs"))

        // Test equals()
        val lengthSelection2 = HairStyleSelection.Length(LengthPreset.MEDIUM)
        assertEquals(lengthSelection, lengthSelection2)
        assert(lengthSelection != accessorySelection)

        // Test hashCode()
        assertEquals(lengthSelection.hashCode(), lengthSelection2.hashCode())
    }
}
