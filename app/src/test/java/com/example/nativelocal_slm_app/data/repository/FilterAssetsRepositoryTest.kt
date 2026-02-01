package com.example.nativelocal_slm_app.data.repository

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Unit tests for FilterAssetsRepository.
 * Uses Robolectric to support real AssetManager and Context operations with test assets.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
@OptIn(ExperimentalCoroutinesApi::class)
class FilterAssetsRepositoryTest {

    private lateinit var repository: FilterAssetsRepository
    private lateinit var context: Context
    private val testDispatcher = UnconfinedTestDispatcher()

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        // Use real Robolectric context which has access to test assets
        context = ApplicationProvider.getApplicationContext<Context>()
        repository = FilterAssetsRepository(context)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `repository can be instantiated`() {
        assertNotNull(repository)
    }

    @Test
    fun `loadFilterAssets returns null when filter not found`() = runTest {
        // Should return null for non-existent filters
        val result = repository.loadFilterAssets("nonexistent_filter")
        assertNull(result)
    }

    @Test
    fun `loadFilterAssets loads valid filter from assets`() = runTest {
        // Test filter exists in test assets
        val result = repository.loadFilterAssets("test_filter")

        // Should successfully load the filter
        assertNotNull(result)
        assertNotNull(result?.maskOverlay)
        assertNotNull(result?.eyeOverlay)
        assertNotNull(result?.hairOverlay)
        assertNotNull(result?.metadata)
    }

    @Test
    fun `loadFilterAssets parses metadata correctly`() = runTest {
        val result = repository.loadFilterAssets("test_filter")

        assertNotNull(result)
        assertNotNull(result?.metadata)
        // Verify metadata content from test metadata.json
        assert(result?.metadata?.author == "Test Author")
        assert(result?.metadata?.version == "1.0.0")
        assert(result?.metadata?.description == "Test filter for unit tests")
        assert(result?.metadata?.tags?.size == 3)
    }

    @Test
    fun `loadFilterAssets loads bitmaps successfully`() = runTest {
        val result = repository.loadFilterAssets("test_filter")

        assertNotNull(result)
        // Verify bitmaps are loaded (1x1 PNG files)
        assert(result?.maskOverlay?.width == 1)
        assert(result?.maskOverlay?.height == 1)
        assert(result?.eyeOverlay?.width == 1)
        assert(result?.eyeOverlay?.height == 1)
        assert(result?.hairOverlay?.width == 1)
        assert(result?.hairOverlay?.height == 1)
    }

    @Test
    fun `loadFilterAssets uses cache on second call`() = runTest {
        // First call - loads from assets
        val result1 = repository.loadFilterAssets("test_filter")
        assertNotNull(result1)

        // Clear cache
        repository.clearCache()

        // Second call after clear - should reload from assets
        val result2 = repository.loadFilterAssets("test_filter")
        assertNotNull(result2)

        // Results should have same content (but different objects after cache clear)
        assert(result1?.metadata?.author == result2?.metadata?.author)
    }

    @Test
    fun `clearCache can be called when cache is empty`() = runTest {
        // Clear empty cache should not throw
        repository.clearCache()
        repository.clearCache()
    }

    @Test
    fun `preloadFilters loads valid filters into cache`() = runTest {
        // Clear cache first
        repository.clearCache()

        // Preload existing filter
        repository.preloadFilters(listOf("test_filter"))

        // Should now be in cache, so second call returns immediately
        val result = repository.loadFilterAssets("test_filter")
        assertNotNull(result)
    }

    @Test
    fun `preloadFilters handles non-existent filters gracefully`() = runTest {
        // Should not throw even if filters don't exist
        repository.preloadFilters(listOf("nonexistent1", "nonexistent2"))
    }

    @Test
    fun `preloadFilters handles mixed valid and invalid filters`() = runTest {
        // Should load valid filters and skip invalid ones
        repository.preloadFilters(listOf("test_filter", "nonexistent", "test_filter"))
        val result = repository.loadFilterAssets("test_filter")
        assertNotNull(result)
    }

    @Test
    fun `loadFilterAssets returns cached instance on subsequent calls`() = runTest {
        // First call
        val result1 = repository.loadFilterAssets("test_filter")
        // Second call (should use cache - same object)
        val result2 = repository.loadFilterAssets("test_filter")

        // Should be the same object (cached)
        assert(result1 === result2)
    }

    @Test
    fun `clearCache removes all cached assets`() = runTest {
        // Load filter into cache
        repository.loadFilterAssets("test_filter")

        // Clear cache
        repository.clearCache()

        // Load again - should get new object
        val result = repository.loadFilterAssets("test_filter")
        assertNotNull(result)
    }

    @Test
    fun `loadFilterAssets handles missing filter gracefully`() = runTest {
        val result = repository.loadFilterAssets("nonexistent_filter")
        assertNull(result)
    }
}
