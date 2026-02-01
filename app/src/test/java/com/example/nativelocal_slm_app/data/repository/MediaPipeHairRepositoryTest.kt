package com.example.nativelocal_slm_app.data.repository

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Unit tests for MediaPipeHairRepository.
 * Uses Robolectric to support Bitmap operations.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
@OptIn(ExperimentalCoroutinesApi::class)
class MediaPipeHairRepositoryTest {

    private lateinit var repository: MediaPipeHairRepository
    private val context: Context = mockk()
    private val testDispatcher = UnconfinedTestDispatcher()

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        every { context.applicationContext } returns context
        repository = MediaPipeHairRepository(context)
    }

    @After
    fun tearDown() {
        repository.release()
        Dispatchers.resetMain()
    }

    @Test
    fun `analyzeHair returns valid HairAnalysisResult`() = runTest {
        val bitmap = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)

        val result = repository.analyzeHair(bitmap)

        assert(result != null)
        assert(result.segmentationMask != null)
        assert(result.hairAnalysis != null)
        assert(result.hairColor != null)
        assert(result.faceLandmarks != null)
    }

    @Test
    fun `analyzeHair measures processing time`() = runTest {
        val bitmap = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)

        val result = repository.analyzeHair(bitmap)

        assert(result.processingTimeMs >= 0)
    }

    @Test
    fun `analyzeHair creates mask with correct dimensions`() = runTest {
        val bitmap = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)

        val result = repository.analyzeHair(bitmap)

        assert(result.segmentationMask != null)
        assert(result.segmentationMask!!.width == bitmap.width)
        assert(result.segmentationMask!!.height == bitmap.height)
    }

    @Test
    fun `analyzeHair creates face landmarks with valid bounding box`() = runTest {
        val bitmap = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)

        val result = repository.analyzeHair(bitmap)

        assert(result.faceLandmarks != null)
        val bbox = result.faceLandmarks!!.boundingBox
        assert(bbox.left >= 0)
        assert(bbox.top >= 0)
        assert(bbox.right <= bitmap.width)
        assert(bbox.bottom <= bitmap.height)
        assert(bbox.left < bbox.right)
        assert(bbox.top < bbox.bottom)
    }

    @Test
    fun `analyzeHair creates face landmarks with expected key points`() = runTest {
        val bitmap = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)

        val result = repository.analyzeHair(bitmap)

        assert(result.faceLandmarks != null)
        val keyPoints = result.faceLandmarks!!.keyPoints
        assert(keyPoints.isNotEmpty())
        // Should have at least the 4 basic landmarks
        assert(keyPoints.size >= 4)
    }

    @Test
    fun `analyzeHair returns valid hair analysis`() = runTest {
        val bitmap = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)

        val result = repository.analyzeHair(bitmap)

        assert(result.hairAnalysis.hairType != null)
        assert(result.hairAnalysis.hairLength != null)
        assert(result.hairAnalysis.textureScore >= 0f)
        assert(result.hairAnalysis.volumeEstimate >= 0f)
        assert(result.hairAnalysis.confidence >= 0f)
    }

    @Test
    fun `analyzeHair returns valid hair color info`() = runTest {
        val bitmap = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)

        val result = repository.analyzeHair(bitmap)

        assert(result.hairColor.primaryColor != null)
        assert(result.hairColor.brightness >= 0f)
        assert(result.hairColor.saturation >= 0f)
    }

    @Test
    fun `segmentHair returns valid bitmap mask`() = runTest {
        val bitmap = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)

        val mask = repository.segmentHair(bitmap)

        assert(mask != null)
        assert(mask!!.width == bitmap.width)
        assert(mask.height == bitmap.height)
    }

    @Test
    fun `segmentHair returns mask with correct dimensions`() = runTest {
        val bitmap = Bitmap.createBitmap(200, 150, Bitmap.Config.ARGB_8888)

        val mask = repository.segmentHair(bitmap)

        assert(mask?.width == 200)
        assert(mask?.height == 150)
    }

    @Test
    fun `detectFaceLandmarks returns valid landmarks`() = runTest {
        val bitmap = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)

        val landmarks = repository.detectFaceLandmarks(bitmap)

        assert(landmarks != null)
        assert(landmarks!!.boundingBox.left >= 0)
        assert(landmarks.boundingBox.top >= 0)
        assert(landmarks.keyPoints.isNotEmpty())
    }

    @Test
    fun `detectFaceLandmarks returns confidence score`() = runTest {
        val bitmap = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)

        val landmarks = repository.detectFaceLandmarks(bitmap)

        assert(landmarks != null)
        assert(landmarks!!.confidence >= 0f)
        assert(landmarks.confidence <= 1f)
    }

    @Test
    fun `detectFaceLandmarks bounding box is within image bounds`() = runTest {
        val bitmap = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)

        val landmarks = repository.detectFaceLandmarks(bitmap)

        assert(landmarks != null)
        val bbox = landmarks!!.boundingBox
        assert(bbox.left >= 0 && bbox.left <= bitmap.width)
        assert(bbox.top >= 0 && bbox.top <= bitmap.height)
        assert(bbox.right >= 0 && bbox.right <= bitmap.width)
        assert(bbox.bottom >= 0 && bbox.bottom <= bitmap.height)
    }

    @Test
    fun `release can be called multiple times safely`() {
        repository.release()
        repository.release()
        repository.release()

        // Should not throw
    }

    @Test
    fun `analyzeHair handles different image sizes`() = runTest {
        val sizes = listOf(
            Pair(50, 50),
            Pair(100, 100),
            Pair(200, 150),
            Pair(640, 480)
        )

        for ((width, height) in sizes) {
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val result = repository.analyzeHair(bitmap)

            assert(result.segmentationMask != null)
            assert(result.segmentationMask!!.width == width)
            assert(result.segmentationMask!!.height == height)
        }
    }

    @Test
    fun `analyzeHair key points have valid coordinates`() = runTest {
        val bitmap = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)

        val result = repository.analyzeHair(bitmap)

        assert(result.faceLandmarks != null)
        result.faceLandmarks!!.keyPoints.values.forEach { point ->
            assert(point.x >= 0f)
            assert(point.y >= 0f)
            assert(point.x <= bitmap.width)
            assert(point.y <= bitmap.height)
        }
    }

    @Test
    fun `segmentHair returns valid bitmap for tiny image`() = runTest {
        // Creating a 0x0 bitmap throws IllegalArgumentException, so test with a minimal valid bitmap
        val result = repository.segmentHair(Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888))
        // The stub implementation creates a placeholder even for tiny bitmaps
        assert(result != null)
    }
}
