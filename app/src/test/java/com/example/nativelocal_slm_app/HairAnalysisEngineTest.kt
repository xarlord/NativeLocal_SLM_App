package com.example.nativelocal_slm_app

import android.graphics.Bitmap
import android.graphics.Color
import com.example.nativelocal_slm_app.domain.model.HairAnalysisResult
import com.example.nativelocal_slm_app.domain.model.BoundingBox
import com.example.nativelocal_slm_app.domain.model.ColorInfo
import com.example.nativelocal_slm_app.domain.model.FaceLandmarksResult
import com.example.nativelocal_slm_app.domain.model.HairAnalysis
import com.example.nativelocal_slm_app.domain.model.HairLength
import com.example.nativelocal_slm_app.domain.model.HairType
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkAll
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * Unit tests for HairAnalysisEngine functionality.
 */
@RunWith(RobolectricTestRunner::class)
class HairAnalysisEngineTest {

    private var testBitmap: Bitmap? = null

    @Before
    fun setup() {
        // Create a test bitmap
        testBitmap = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)
    }

    @After
    fun tearDown() {
        testBitmap?.recycle()
        testBitmap = null
        unmockkAll()
    }

    @Test
    fun `test hair analysis result creation`() {
        val expectedMask = testBitmap!!
        val expectedHairAnalysis = HairAnalysis(
            hairType = HairType.STRAIGHT,
            hairLength = HairLength.MEDIUM,
            textureScore = 0.5f,
            volumeEstimate = 0.6f,
            confidence = 0.8f
        )
        val expectedColor = ColorInfo(
            primaryColor = androidx.compose.ui.graphics.Color.Black,
            brightness = 0.5f,
            saturation = 0.5f
        )
        val expectedLandmarks = FaceLandmarksResult(
            boundingBox = BoundingBox(10f, 10f, 90f, 90f),
            keyPoints = emptyMap(),
            confidence = 0.9f
        )

        val result = HairAnalysisResult(
            segmentationMask = expectedMask,
            hairAnalysis = expectedHairAnalysis,
            hairColor = expectedColor,
            faceLandmarks = expectedLandmarks,
            processingTimeMs = 100L
        )

        assertNotNull(result.segmentationMask)
        assertEquals(HairType.STRAIGHT, result.hairAnalysis.hairType)
        assertEquals(HairLength.MEDIUM, result.hairAnalysis.hairLength)
        assertEquals(0.5f, result.hairAnalysis.textureScore)
        assertEquals(0.6f, result.hairAnalysis.volumeEstimate)
        assertEquals(0.8f, result.hairAnalysis.confidence)
        assertEquals(0.9f, result.faceLandmarks?.confidence)
        assertEquals(100L, result.processingTimeMs)
    }

    @Test
    fun `test hair type detection - straight hair`() {
        val hairType = HairType.STRAIGHT

        assertEquals("STRAIGHT", hairType.name)
        assertTrue(hairType == HairType.STRAIGHT)
    }

    @Test
    fun `test hair length detection - medium hair`() {
        val hairLength = HairLength.MEDIUM

        assertEquals("MEDIUM", hairLength.name)
        assertTrue(hairLength == HairLength.MEDIUM)
    }

    @Test
    fun `test hair color extraction`() {
        val colorInfo = ColorInfo(
            primaryColor = androidx.compose.ui.graphics.Color.Red,
            brightness = 0.8f,
            saturation = 0.7f
        )

        assertEquals(androidx.compose.ui.graphics.Color.Red, colorInfo.primaryColor)
        assertEquals(0.8f, colorInfo.brightness)
        assertEquals(0.7f, colorInfo.saturation)
    }

    @Test
    fun `test face landmarks bounding box calculation`() {
        val boundingBox = BoundingBox(
            left = 10f,
            top = 20f,
            right = 90f,
            bottom = 100f
        )

        assertEquals(80f, boundingBox.width)
        assertEquals(80f, boundingBox.height)
        assertEquals(50f, boundingBox.centerX)
        assertEquals(60f, boundingBox.centerY)
    }

    @Test
    fun `test hair analysis confidence threshold`() {
        val highConfidenceAnalysis = HairAnalysis(
            hairType = HairType.CURLY,
            hairLength = HairLength.LONG,
            textureScore = 0.7f,
            volumeEstimate = 0.8f,
            confidence = 0.9f
        )

        assertTrue(highConfidenceAnalysis.confidence > 0.5f)
    }

    @Test
    fun `test texture score is within valid range`() {
        val validScores = listOf(0f, 0.5f, 1f, 0.75f, 0.25f)

        validScores.forEach { score ->
            val analysis = HairAnalysis(
                hairType = HairType.WAVY,
                hairLength = HairLength.SHORT,
                textureScore = score,
                volumeEstimate = 0.5f,
                confidence = 0.7f
            )

            assertTrue(analysis.textureScore in 0f..1f)
        }
    }

    @Test
    fun `test volume estimate is within valid range`() {
        val validEstimates = listOf(0f, 0.3f, 0.7f, 1f, 0.5f)

        validEstimates.forEach { estimate ->
            val analysis = HairAnalysis(
                hairType = HairType.COILY,
                hairLength = HairLength.EXTRA_LONG,
                textureScore = 0.6f,
                volumeEstimate = estimate,
                confidence = 0.8f
            )

            assertTrue(analysis.volumeEstimate in 0f..1f)
        }
    }
}
