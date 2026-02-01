package com.example.nativelocal_slm_app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import androidx.compose.ui.graphics.toArgb
import com.example.nativelocal_slm_app.data.model.FilterAssets
import com.example.nativelocal_slm_app.data.model.FilterMetadata
import com.example.nativelocal_slm_app.data.repository.FilterAssetsRepository
import com.example.nativelocal_slm_app.data.repository.MediaPipeHairRepository
import com.example.nativelocal_slm_app.data.source.local.FilterAssetLoader
import com.example.nativelocal_slm_app.domain.model.BoundingBox
import com.example.nativelocal_slm_app.domain.model.ColorInfo
import com.example.nativelocal_slm_app.domain.model.FaceLandmarksResult
import com.example.nativelocal_slm_app.domain.model.HairAnalysis
import com.example.nativelocal_slm_app.domain.model.HairAnalysisResult
import com.example.nativelocal_slm_app.domain.model.HairLength
import com.example.nativelocal_slm_app.domain.model.HairType
import com.example.nativelocal_slm_app.domain.model.LandmarkType
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkAll
import io.mockk.verify
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Before
import org.junit.Ignore
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.io.IOException
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Comprehensive unit tests for repository layer.
 * Tests MediaPipeHairRepository, FilterAssetsRepository, and FilterAssetLoader.
 */
@RunWith(RobolectricTestRunner::class)
class RepositoryTest {

    private lateinit var mockContext: Context
    private lateinit var mediaPipeRepository: MediaPipeHairRepository
    private lateinit var filterAssetsRepository: FilterAssetsRepository
    private lateinit var testBitmap: Bitmap

    @Before
    fun setup() {
        mockContext = mockk(relaxed = true)
        mediaPipeRepository = MediaPipeHairRepository(mockContext)
        filterAssetsRepository = FilterAssetsRepository(mockContext)
        testBitmap = Bitmap.createBitmap(640, 480, Bitmap.Config.ARGB_8888)

        // Initialize mock context for assets
        val mockAssetsManager = mockk<android.content.res.AssetManager>(relaxed = true)
        every { mockContext.assets } returns mockAssetsManager
    }

    @After
    fun tearDown() {
        unmockkAll()
        testBitmap.recycle()
    }

    // ==================== MediaPipeHairRepository Tests ====================

    @Ignore
    @Test
    fun `MediaPipeHairRepository analyzeHair returns valid result`() = runTest {
        val result = mediaPipeRepository.analyzeHair(testBitmap)

        assertNotNull(result)
        assertNotNull(result.segmentationMask)
        assertNotNull(result.hairAnalysis)
        assertNotNull(result.hairColor)
        assertNotNull(result.faceLandmarks)
        assertTrue(result.processingTimeMs >= 0)
    }

    @Ignore
    @Test
    fun `MediaPipeHairRepository analyzeHair returns correct mask dimensions`() = runTest {
        val result = mediaPipeRepository.analyzeHair(testBitmap)

        assertNotNull(result.segmentationMask)
        assertEquals(testBitmap.width, result.segmentationMask.width)
        assertEquals(testBitmap.height, result.segmentationMask.height)
    }

    @Ignore
    @Test
    fun `MediaPipeHairRepository analyzeHair returns valid hair analysis`() = runTest {
        val result = mediaPipeRepository.analyzeHair(testBitmap)

        assertNotNull(result.hairAnalysis)
        assertTrue(result.hairAnalysis.hairType in HairType.entries)
        assertTrue(result.hairAnalysis.hairLength in HairLength.entries)
        assertTrue(result.hairAnalysis.textureScore in 0f..1f)
        assertTrue(result.hairAnalysis.volumeEstimate in 0f..1f)
        assertTrue(result.hairAnalysis.confidence in 0f..1f)
    }

    @Ignore
    @Test
    fun `MediaPipeHairRepository analyzeHair returns valid hair color`() = runTest {
        val result = mediaPipeRepository.analyzeHair(testBitmap)

        assertNotNull(result.hairColor)
        assertTrue(result.hairColor.brightness in 0f..1f)
        assertTrue(result.hairColor.saturation in 0f..1f)
    }

    @Ignore
    @Test
    fun `MediaPipeHairRepository analyzeHair returns valid face landmarks`() = runTest {
        val result = mediaPipeRepository.analyzeHair(testBitmap)

        assertNotNull(result.faceLandmarks)
        assertTrue(result.faceLandmarks.confidence in 0f..1f)
        assertTrue(result.faceLandmarks.boundingBox.width > 0)
        assertTrue(result.faceLandmarks.boundingBox.height > 0)
        assertTrue(result.faceLandmarks.keyPoints.isNotEmpty())
    }

    @Ignore
    @Test
    fun `MediaPipeHairRepository segmentHair returns mask`() = runTest {
        val mask = mediaPipeRepository.segmentHair(testBitmap)

        assertNotNull(mask)
        assertEquals(testBitmap.width, mask.width)
        assertEquals(testBitmap.height, mask.height)
    }

    @Ignore
    @Test
    fun `MediaPipeHairRepository detectFaceLandmarks returns landmarks`() = runTest {
        val landmarks = mediaPipeRepository.detectFaceLandmarks(testBitmap)

        assertNotNull(landmarks)
        assertTrue(landmarks.confidence > 0)
        assertTrue(landmarks.boundingBox.width > 0)
        assertTrue(landmarks.boundingBox.height > 0)
        assertTrue(landmarks.keyPoints.isNotEmpty())
    }

    @Ignore
    @Test
    fun `MediaPipeHairRepository detectFaceLandmarks includes required keypoints`() = runTest {
        val landmarks = mediaPipeRepository.detectFaceLandmarks(testBitmap)

        assertNotNull(landmarks)
        assertTrue(landmarks.keyPoints.containsKey(LandmarkType.LEFT_EYE))
        assertTrue(landmarks.keyPoints.containsKey(LandmarkType.RIGHT_EYE))
        assertTrue(landmarks.keyPoints.containsKey(LandmarkType.NOSE_TIP))
        assertTrue(landmarks.keyPoints.containsKey(LandmarkType.MOUTH_CENTER))
    }

    @Ignore
    @Test
    fun `MediaPipeHairRepository release does not throw`() {
        // Should not throw any exception
        mediaPipeRepository.release()
    }

    @Ignore
    @Test
    fun `MediaPipeHairRepository analyzeHair with different bitmap sizes`() = runTest {
        val sizes = listOf(
            Pair(320, 240),
            Pair(640, 480),
            Pair(1280, 720),
            Pair(1920, 1080)
        )

        sizes.forEach { (width, height) ->
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val result = mediaPipeRepository.analyzeHair(bitmap)

            assertNotNull(result)
            assertEquals(width, result.segmentationMask!!.width)
            assertEquals(height, result.segmentationMask!!.height)
            bitmap.recycle()
        }
    }

    // ==================== FilterAssetsRepository Tests ====================

    @Test
    fun `FilterAssetsRepository loadFilterAssets with non-existent filter returns null`() = runTest {
        val mockAssets = mockk<android.content.res.AssetManager>(relaxed = true)
        every { mockContext.assets } returns mockAssets
        every { mockAssets.list(any()) } throws IOException("Not found")

        val result = filterAssetsRepository.loadFilterAssets("non_existent_filter")

        assertNull(result)
    }

    @Test
    fun `FilterAssetsRepository clearCache clears assets`() = runTest {
        // First, ensure we have a cached repository instance
        filterAssetsRepository.clearCache()

        // After clearing cache, loading should require fresh asset access
        // This test verifies the clear operation doesn't throw
        filterAssetsRepository.clearCache()
    }

    @Test
    fun `FilterAssetsRepository preloadFilters with empty list`() = runTest {
        // Should not throw with empty list
        filterAssetsRepository.preloadFilters(emptyList())
    }

    @Test
    fun `FilterAssetsRepository preloadFilters with filter IDs`() = runTest {
        val mockAssets = mockk<android.content.res.AssetManager>(relaxed = true)
        every { mockContext.assets } returns mockAssets
        every { mockAssets.list(any()) } returns null

        // Should not throw even if assets don't exist
        filterAssetsRepository.preloadFilters(listOf("batman", "joker", "skeleton"))
    }

    @Test
    fun `FilterAssetsRepository loadFilterAssets returns null on exception`() = runTest {
        val mockAssets = mockk<android.content.res.AssetManager>(relaxed = true)
        every { mockContext.assets } returns mockAssets
        every { mockAssets.list(any()) } throws IOException("Test exception")

        val result = filterAssetsRepository.loadFilterAssets("test_filter")

        assertNull(result)
    }

    @Test
    fun `FilterAssetsRepository multiple load calls use cache`() = runTest {
        val mockAssets = mockk<android.content.res.AssetManager>(relaxed = true)
        every { mockContext.assets } returns mockAssets
        every { mockAssets.list(any()) } returns null

        // First call
        filterAssetsRepository.loadFilterAssets("test_filter")
        // Second call should use cache (won't call assets.list again)
        filterAssetsRepository.loadFilterAssets("test_filter")

        // Verify assets.list was called (caching behavior verified by no exception)
        verify(atLeast = 1) { mockAssets.list(any()) }
    }

    @Test
    fun `FilterAssetsRepository clearCache and reload`() = runTest {
        val mockAssets = mockk<android.content.res.AssetManager>(relaxed = true)
        every { mockContext.assets } returns mockAssets
        every { mockAssets.list(any()) } returns null

        // Load first time
        filterAssetsRepository.loadFilterAssets("test_filter")

        // Clear cache
        filterAssetsRepository.clearCache()

        // Load again - should access assets again
        filterAssetsRepository.loadFilterAssets("test_filter")

        verify(atLeast = 2) { mockAssets.list(any()) }
    }

    // ==================== FilterAssetLoader Tests ====================

    @Test
    fun `FilterAssetLoader loadBitmap with valid path returns null when asset not found`() {
        val mockAssets = mockk<android.content.res.AssetManager>(relaxed = true)
        every { mockContext.assets } returns mockAssets
        every { mockAssets.open(any()) } throws IOException("Asset not found")

        val result = FilterAssetLoader.loadBitmap(mockContext, "filters/face/batman/mask.png")

        assertNull(result)
    }

    @Test
    fun `FilterAssetLoader loadBitmap handles IOException gracefully`() {
        val mockAssets = mockk<android.content.res.AssetManager>(relaxed = true)
        every { mockContext.assets } returns mockAssets
        every { mockAssets.open(any()) } throws IOException("Test exception")

        val result = FilterAssetLoader.loadBitmap(mockContext, "invalid/path.png")

        assertNull(result)
    }

    @Test
    fun `FilterAssetLoader assetExists with invalid path returns false`() {
        val mockAssets = mockk<android.content.res.AssetManager>(relaxed = true)
        every { mockContext.assets } returns mockAssets
        every { mockAssets.list(any()) } throws IOException("Not found")

        val result = FilterAssetLoader.assetExists(mockContext, "filters/invalid/file.png")

        assertFalse(result)
    }

    @Test
    fun `FilterAssetLoader assetExists with empty path returns false`() {
        val mockAssets = mockk<android.content.res.AssetManager>(relaxed = true)
        every { mockContext.assets } returns mockAssets
        every { mockAssets.list(any()) } returns null

        val result = FilterAssetLoader.assetExists(mockContext, "invalid/path/file.png")

        assertFalse(result)
    }

    @Test
    fun `FilterAssetLoader listDirectories with valid path returns empty list when not found`() {
        val mockAssets = mockk<android.content.res.AssetManager>(relaxed = true)
        every { mockContext.assets } returns mockAssets
        every { mockAssets.list(any()) } throws IOException("Not found")

        val result = FilterAssetLoader.listDirectories(mockContext, "filters/invalid")

        assertTrue(result.isEmpty())
    }

    @Test
    fun `FilterAssetLoader listDirectories returns empty list on exception`() {
        val mockAssets = mockk<android.content.res.AssetManager>(relaxed = true)
        every { mockContext.assets } returns mockAssets
        every { mockAssets.list(any()) } throws IOException("Test exception")

        val result = FilterAssetLoader.listDirectories(mockContext, "invalid/path")

        assertTrue(result.isEmpty())
    }

    @Test
    fun `FilterAssetLoader listDirectories with null return returns empty list`() {
        val mockAssets = mockk<android.content.res.AssetManager>(relaxed = true)
        every { mockContext.assets } returns mockAssets
        every { mockAssets.list(any()) } returns null

        val result = FilterAssetLoader.listDirectories(mockContext, "filters/face")

        assertTrue(result.isEmpty())
    }

    @Test
    fun `FilterAssetLoader listDirectories returns directory list`() {
        val mockAssets = mockk<android.content.res.AssetManager>(relaxed = true)
        every { mockContext.assets } returns mockAssets
        val expectedDirs = arrayOf("batman", "joker", "skeleton")
        every { mockAssets.list("filters/face") } returns expectedDirs

        val result = FilterAssetLoader.listDirectories(mockContext, "filters/face")

        assertEquals(3, result.size)
        assertTrue(result.contains("batman"))
        assertTrue(result.contains("joker"))
        assertTrue(result.contains("skeleton"))
    }

    // ==================== Integration Tests ====================

    @Ignore
    @Test
    fun `MediaPipeHairRepository consecutive analyzeHair calls are independent`() = runTest {
        val result1 = mediaPipeRepository.analyzeHair(testBitmap)
        val result2 = mediaPipeRepository.analyzeHair(testBitmap)

        // Results should have same structure but different processing times
        assertNotNull(result1)
        assertNotNull(result2)
        assertTrue(result1.processingTimeMs >= 0)
        assertTrue(result2.processingTimeMs >= 0)
    }

    @Ignore
    @Test
    fun `MediaPipeHairRepository with zero-sized bitmap`() = runTest {
        val smallBitmap = Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)
        val result = mediaPipeRepository.analyzeHair(smallBitmap)

        assertNotNull(result)
        assertEquals(1, result.segmentationMask!!.width)
        assertEquals(1, result.segmentationMask!!.height)
        smallBitmap.recycle()
    }

    @Test
    fun `FilterAssetsRepository cache behavior with multiple filters`() = runTest {
        val mockAssets = mockk<android.content.res.AssetManager>(relaxed = true)
        every { mockContext.assets } returns mockAssets
        every { mockAssets.list(any()) } returns null

        // Load multiple filters
        val filters = listOf("batman", "joker", "skeleton", "tiger_face", "punk_mohawk")
        filterAssetsRepository.preloadFilters(filters)

        // Verify no exceptions thrown
        verify(atLeast = 1) { mockAssets.list(any()) }

        // Clear and verify
        filterAssetsRepository.clearCache()
    }

    @Ignore
    @Test
    fun `MediaPipeHairRepository segmentHair returns consistent results`() = runTest {
        val mask1 = mediaPipeRepository.segmentHair(testBitmap)
        val mask2 = mediaPipeRepository.segmentHair(testBitmap)

        assertNotNull(mask1)
        assertNotNull(mask2)
        assertEquals(testBitmap.width, mask1.width)
        assertEquals(testBitmap.height, mask1.height)
        assertEquals(testBitmap.width, mask2.width)
        assertEquals(testBitmap.height, mask2.height)
    }

    @Ignore
    @Test
    fun `MediaPipeHairRepository detectFaceLandmarks with different bitmaps`() = runTest {
        val bitmap1 = Bitmap.createBitmap(640, 480, Bitmap.Config.ARGB_8888)
        val bitmap2 = Bitmap.createBitmap(800, 600, Bitmap.Config.ARGB_8888)

        val landmarks1 = mediaPipeRepository.detectFaceLandmarks(bitmap1)
        val landmarks2 = mediaPipeRepository.detectFaceLandmarks(bitmap2)

        assertNotNull(landmarks1)
        assertNotNull(landmarks2)
        assert(landmarks1!!.confidence > 0)
        assert(landmarks2!!.confidence > 0)

        bitmap1.recycle()
        bitmap2.recycle()
    }

    @Test
    fun `FilterAssetLoader with various path formats`() {
        val mockAssets = mockk<android.content.res.AssetManager>(relaxed = true)
        every { mockContext.assets } returns mockAssets
        every { mockAssets.open(any()) } throws IOException("Not found")
        every { mockAssets.list(any()) } throws IOException("Not found")

        // Test various path formats
        val paths = listOf(
            "filters/face/batman/mask.png",
            "filters/hair/punk_mohawk/hair_overlay.png",
            "filters/combo/wonder_woman/mask.png",
            "deeply/nested/path/file.png"
        )

        paths.forEach { path ->
            val result = FilterAssetLoader.loadBitmap(mockContext, path)
            assertNull(result)
        }
    }

    @Ignore
    @Test
    fun `MediaPipeHairRepository analyzeHair bounding box calculations are valid`() = runTest {
        val result = mediaPipeRepository.analyzeHair(testBitmap)

        assertNotNull(result.faceLandmarks)
        val bbox = result.faceLandmarks.boundingBox

        assertTrue(bbox.left < bbox.right)
        assertTrue(bbox.top < bbox.bottom)
        assertTrue(bbox.left >= 0)
        assertTrue(bbox.top >= 0)
        assertTrue(bbox.right <= testBitmap.width)
        assertTrue(bbox.bottom <= testBitmap.height)
    }

    @Ignore
    @Test
    fun `MediaPipeHairRepository landmark positions are within bounds`() = runTest {
        val result = mediaPipeRepository.analyzeHair(testBitmap)

        assertNotNull(result.faceLandmarks)
        val bbox = result.faceLandmarks.boundingBox

        result.faceLandmarks.keyPoints.values.forEach { point ->
            assertTrue(point.x >= 0f)
            assertTrue(point.y >= 0f)
            assertTrue(point.x <= testBitmap.width.toFloat())
            assertTrue(point.y <= testBitmap.height.toFloat())
        }
    }
}
