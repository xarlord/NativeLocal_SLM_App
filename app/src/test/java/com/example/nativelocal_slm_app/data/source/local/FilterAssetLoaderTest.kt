package com.example.nativelocal_slm_app.data.source.local

import android.content.Context
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import io.mockk.verify
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.ByteArrayInputStream
import java.io.IOException

/**
 * Unit tests for FilterAssetLoader.
 * Uses Robolectric for Android Context and Assets support.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class FilterAssetLoaderTest {

    private lateinit var mockContext: Context
    private lateinit var mockAssetsManager: android.content.res.AssetManager

    @Before
    fun setup() {
        mockContext = mockk(relaxed = true)
        mockAssetsManager = mockk(relaxed = true)
        every { mockContext.assets } returns mockAssetsManager
    }

    @After
    fun tearDown() {
        // Clean up any static mocks
        try {
            unmockkStatic(android.graphics.BitmapFactory::class)
        } catch (e: Exception) {
            // Ignore if not mocked
        }
    }

    @Test
    fun `loadBitmap returns null when asset throws IOException`() {
        every { mockAssetsManager.open("filters/face/batman/mask.png") } throws IOException("Asset not found")

        val result = FilterAssetLoader.loadBitmap(mockContext, "filters/face/batman/mask.png")

        assertEquals(null, result)
    }

    @Test
    fun `loadBitmap calls assets open with correct path`() {
        every { mockAssetsManager.open("filters/face/batman/mask.png") } throws IOException("Not found")

        FilterAssetLoader.loadBitmap(mockContext, "filters/face/batman/mask.png")

        verify(exactly = 1) { mockAssetsManager.open("filters/face/batman/mask.png") }
    }

    @Test
    fun `loadBitmap with empty path returns null`() {
        every { mockAssetsManager.open("") } throws IOException("Empty path")

        val result = FilterAssetLoader.loadBitmap(mockContext, "")

        assertEquals(null, result)
    }

    @Test
    fun `loadBitmap with nested path`() {
        every { mockAssetsManager.open("filters/hair/punk/mohawk/overlay.png") } throws IOException("Not found")

        FilterAssetLoader.loadBitmap(mockContext, "filters/hair/punk/mohawk/overlay.png")

        verify(exactly = 1) { mockAssetsManager.open("filters/hair/punk/mohawk/overlay.png") }
    }

    @Test
    fun `assetExists returns true when file is in list`() {
        every { mockAssetsManager.list("filters/face") } returns arrayOf("batman", "joker", "tiger")

        val result = FilterAssetLoader.assetExists(mockContext, "filters/face/batman")

        assertEquals(true, result)
    }

    @Test
    fun `assetExists returns false when file is not in list`() {
        every { mockAssetsManager.list("filters/face") } returns arrayOf("batman", "joker")

        val result = FilterAssetLoader.assetExists(mockContext, "filters/face/tiger")

        assertEquals(false, result)
    }

    @Test
    fun `assetExists returns false when list returns null`() {
        every { mockAssetsManager.list("filters/face") } returns null

        val result = FilterAssetLoader.assetExists(mockContext, "filters/face/batman")

        assertEquals(false, result)
    }

    @Test
    fun `assetExists returns false when IOException is thrown`() {
        every { mockAssetsManager.list("invalid/path") } throws IOException("Path not found")

        val result = FilterAssetLoader.assetExists(mockContext, "invalid/path/file.png")

        assertEquals(false, result)
    }

    @Test
    fun `assetExists handles paths with special characters`() {
        every { mockAssetsManager.list("filters/face") } returns arrayOf("cyber-punk", "neo-tokyo")

        val result = FilterAssetLoader.assetExists(mockContext, "filters/face/cyber-punk")

        assertEquals(true, result)
    }

    @Test
    fun `assetExists with empty path`() {
        every { mockAssetsManager.list("") } throws IOException("Empty path")

        val result = FilterAssetLoader.assetExists(mockContext, "")

        assertEquals(false, result)
    }

    @Test
    fun `listDirectories returns list of directory names`() {
        every { mockAssetsManager.list("filters/face") } returns arrayOf("batman", "joker", "skeleton")

        val result = FilterAssetLoader.listDirectories(mockContext, "filters/face")

        assertEquals(3, result.size)
        assertTrue(result.contains("batman"))
        assertTrue(result.contains("joker"))
        assertTrue(result.contains("skeleton"))
    }

    @Test
    fun `listDirectories returns empty list when IOException is thrown`() {
        every { mockAssetsManager.list("invalid/path") } throws IOException("Path not found")

        val result = FilterAssetLoader.listDirectories(mockContext, "invalid/path")

        assertTrue(result.isEmpty())
    }

    @Test
    fun `listDirectories returns empty list when assets list returns null`() {
        every { mockAssetsManager.list("filters/hair") } returns null

        val result = FilterAssetLoader.listDirectories(mockContext, "filters/hair")

        assertTrue(result.isEmpty())
    }

    @Test
    fun `listDirectories returns empty list for non-existent path`() {
        every { mockAssetsManager.list("nonexistent") } throws IOException("Not found")

        val result = FilterAssetLoader.listDirectories(mockContext, "nonexistent")

        assertTrue(result.isEmpty())
    }

    @Test
    fun `listDirectories handles empty directory`() {
        every { mockAssetsManager.list("filters/custom") } returns emptyArray()

        val result = FilterAssetLoader.listDirectories(mockContext, "filters/custom")

        assertTrue(result.isEmpty())
    }

    @Test
    fun `listDirectories calls assets list with correct path`() {
        every { mockAssetsManager.list("filters/combo") } returns arrayOf("wonder-woman", "harley-quinn")

        FilterAssetLoader.listDirectories(mockContext, "filters/combo")

        verify(exactly = 1) { mockAssetsManager.list("filters/combo") }
    }

    @Test
    fun `listDirectories preserves order of directories`() {
        val expected = arrayOf("alpha", "bravo", "charlie", "delta")
        every { mockAssetsManager.list("filters") } returns expected

        val result = FilterAssetLoader.listDirectories(mockContext, "filters")

        assertEquals(expected.size, result.size)
        assertEquals("alpha", result[0])
        assertEquals("bravo", result[1])
        assertEquals("charlie", result[2])
        assertEquals("delta", result[3])
    }

    @Test
    fun `multiple loadBitmap calls with different paths`() {
        every { mockAssetsManager.open("file1.png") } throws IOException()
        every { mockAssetsManager.open("file2.png") } throws IOException()

        FilterAssetLoader.loadBitmap(mockContext, "file1.png")
        FilterAssetLoader.loadBitmap(mockContext, "file2.png")

        verify(exactly = 1) { mockAssetsManager.open("file1.png") }
        verify(exactly = 1) { mockAssetsManager.open("file2.png") }
    }

    @Test
    fun `assetExists is case sensitive`() {
        every { mockAssetsManager.list("filters/face") } returns arrayOf("Batman", "joker", "TIGER")

        val result1 = FilterAssetLoader.assetExists(mockContext, "filters/face/Batman")
        val result2 = FilterAssetLoader.assetExists(mockContext, "filters/face/batman")

        assertEquals(true, result1)
        assertEquals(false, result2)
    }

    @Test
    fun `FilterAssetLoader is an object (singleton)`() {
        // Verify FilterAssetLoader is an object (singleton)
        val instance = FilterAssetLoader
        val sameInstance = FilterAssetLoader

        assertTrue(instance === sameInstance)
    }

    @Test
    fun `loadBitmap handles asset with PNG extension`() {
        every { mockAssetsManager.open("filter.png") } throws IOException("Not found")

        val result = FilterAssetLoader.loadBitmap(mockContext, "filter.png")

        assertEquals(null, result)
        verify(exactly = 1) { mockAssetsManager.open("filter.png") }
    }

    @Test
    fun `loadBitmap handles asset with JPG extension`() {
        every { mockAssetsManager.open("photo.jpg") } throws IOException("Not found")

        val result = FilterAssetLoader.loadBitmap(mockContext, "photo.jpg")

        assertEquals(null, result)
        verify(exactly = 1) { mockAssetsManager.open("photo.jpg") }
    }

    @Test
    fun `listDirectories with root filters path`() {
        every { mockAssetsManager.list("filters") } returns arrayOf("face", "hair", "combo")

        val result = FilterAssetLoader.listDirectories(mockContext, "filters")

        assertEquals(3, result.size)
        assertTrue(result.contains("face"))
        assertTrue(result.contains("hair"))
        assertTrue(result.contains("combo"))
    }
}
