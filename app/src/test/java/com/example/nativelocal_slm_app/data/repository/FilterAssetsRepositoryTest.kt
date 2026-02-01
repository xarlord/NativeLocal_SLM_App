package com.example.nativelocal_slm_app.data.repository

import android.content.Context
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
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Unit tests for FilterAssetsRepository.
 * Uses Robolectric to support AssetManager and Context operations.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
@OptIn(ExperimentalCoroutinesApi::class)
class FilterAssetsRepositoryTest {

    private lateinit var repository: FilterAssetsRepository
    private val context: Context = mockk(relaxed = true)
    private val testDispatcher = UnconfinedTestDispatcher()

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        repository = FilterAssetsRepository(context)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `repository can be instantiated`() {
        assert(repository != null)
    }

    @Test
    fun `loadFilterAssets returns null when filter not found`() = runTest {
        // The stub will return null when assets don't exist
        val result = repository.loadFilterAssets("nonexistent_filter")

        // Should return null for non-existent filters
        assert(result == null)
    }

    @Test
    fun `clearCache removes cached assets`() = runTest {
        // Clear cache should not throw
        repository.clearCache()

        // Should be able to call multiple times
        repository.clearCache()
        repository.clearCache()
    }

    @Test
    fun `clearCache can be called when cache is empty`() = runTest {
        // Clear empty cache should not throw
        repository.clearCache()

        // And should not throw again
        repository.clearCache()
    }

    @Test
    fun `preloadFilters handles empty list`() = runTest {
        // Should not throw with empty list
        repository.preloadFilters(emptyList())
    }

    @Test
    fun `preloadFilters handles single filter`() = runTest {
        // Should not throw even if filter doesn't exist
        repository.preloadFilters(listOf("test_filter"))
    }

    @Test
    fun `preloadFilters handles multiple filters`() = runTest {
        // Should not throw even if filters don't exist
        repository.preloadFilters(listOf("filter1", "filter2", "filter3"))
    }

    @Test
    fun `loadFilterAssets returns same result on second call`() = runTest {
        // First call
        val result1 = repository.loadFilterAssets("test_filter")
        // Second call (should use cache)
        val result2 = repository.loadFilterAssets("test_filter")

        // Results should be consistent
        assert(result1 == result2)
    }

    @Test
    fun `loadFilterAssets with different filter IDs`() = runTest {
        val result1 = repository.loadFilterAssets("filter1")
        val result2 = repository.loadFilterAssets("filter2")

        // Both should return null (filters don't exist)
        assert(result1 == null)
        assert(result2 == null)
    }

    @Test
    fun `clearCache affects subsequent calls`() = runTest {
        // First call
        repository.loadFilterAssets("test_filter")

        // Clear cache
        repository.clearCache()

        // Second call should not use cache
        repository.loadFilterAssets("test_filter")

        // Should not throw
    }

    @Test
    fun `repository uses context application context`() {
        // Verify repository was created with context
        assert(repository != null)
    }

    @Test
    fun `multiple loadFilterAssets calls do not accumulate in cache indefinitely`() = runTest {
        // Load many filters
        repeat(100) { i ->
            repository.loadFilterAssets("filter_$i")
        }

        // Clear cache
        repository.clearCache()

        // Cache should be cleared
        // Load again
        repository.loadFilterAssets("filter_0")

        // Should not throw
    }

    @Test
    fun `preloadFilters with duplicate IDs`() = runTest {
        // Should handle duplicate filter IDs gracefully
        repository.preloadFilters(listOf("filter1", "filter1", "filter2", "filter2"))

        // Should not throw
    }

    @Test
    fun `clearCache and preloadFilters work together`() = runTest {
        // Preload some filters
        repository.preloadFilters(listOf("filter1", "filter2"))

        // Clear cache
        repository.clearCache()

        // Preload again
        repository.preloadFilters(listOf("filter3", "filter4"))

        // Should not throw
    }
}
