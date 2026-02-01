package com.example.nativelocal_slm_app

import com.example.nativelocal_slm_app.data.model.FilterEffect
import com.example.nativelocal_slm_app.data.model.FilterCategory
import com.example.nativelocal_slm_app.data.model.PredefinedFilters
import com.example.nativelocal_slm_app.data.model.PredefinedFilters.batmanFilter
import com.example.nativelocal_slm_app.data.model.PredefinedFilters.jokerFilter
import com.example.nativelocal_slm_app.data.model.PredefinedFilters.getFilterById
import com.example.nativelocal_slm_app.data.model.PredefinedFilters.getFiltersByCategory
import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Unit tests for FilterComposer and filter management.
 */
class FilterComposerTest {

    @Test
    fun `test filter effect creation`() {
        val filter = FilterEffect(
            id = "test_filter",
            name = "Test Filter",
            category = FilterCategory.FACE,
            thumbnailRes = "filters/test/thumbnail.png"
        )

        assertEquals("test_filter", filter.id)
        assertEquals("Test Filter", filter.name)
        assertEquals(FilterCategory.FACE, filter.category)
        assertEquals("filters/test/thumbnail.png", filter.thumbnailRes)
    }

    @Test
    fun `test predefined filters - batman`() {
        assertEquals("batman", batmanFilter.id)
        assertEquals("Batman", batmanFilter.name)
        assertEquals(FilterCategory.FACE, batmanFilter.category)
    }

    @Test
    fun `test predefined filters - joker`() {
        assertEquals("joker", jokerFilter.id)
        assertEquals("Joker", jokerFilter.name)
        assertEquals(FilterCategory.FACE, jokerFilter.category)
    }

    @Test
    fun `test get all filters`() {
        val allFilters = PredefinedFilters.getAllFilters()

        assertTrue(allFilters.isNotEmpty())
        assertTrue(allFilters.any { it.id == "batman" })
        assertTrue(allFilters.any { it.id == "joker" })
        assertTrue(allFilters.any { it.id == "wonder_woman" })
    }

    @Test
    fun `test get filters by category - FACE`() {
        val faceFilters = getFiltersByCategory(FilterCategory.FACE)

        assertTrue(faceFilters.isNotEmpty())
        assertTrue(faceFilters.all { it.category == FilterCategory.FACE })
        assertTrue(faceFilters.any { it.id == "batman" })
        assertTrue(faceFilters.any { it.id == "joker" })
        assertTrue(faceFilters.any { it.id == "skeleton" })
        assertTrue(faceFilters.any { it.id == "tiger_face" })
    }

    @Test
    fun `test get filters by category - HAIR`() {
        val hairFilters = getFiltersByCategory(FilterCategory.HAIR)

        assertTrue(hairFilters.isNotEmpty())
        assertTrue(hairFilters.all { it.category == FilterCategory.HAIR })
        assertTrue(hairFilters.any { it.id == "punk_mohawk" })
        assertTrue(hairFilters.any { it.id == "neon_glow" })
        assertTrue(hairFilters.any { it.id == "fire_hair" })
    }

    @Test
    fun `test get filters by category - COMBO`() {
        val comboFilters = getFiltersByCategory(FilterCategory.COMBO)

        assertTrue(comboFilters.isNotEmpty())
        assertTrue(comboFilters.all { it.category == FilterCategory.COMBO })
        assertTrue(comboFilters.any { it.id == "wonder_woman" })
        assertTrue(comboFilters.any { it.id == "harley_quinn" })
        assertTrue(comboFilters.any { it.id == "cyberpunk" })
    }

    @Test
    fun `test get filter by id - existing filter`() {
        val batman = getFilterById("batman")

        assertNotNull(batman)
        assertEquals("batman", batman?.id)
        assertEquals("Batman", batman?.name)
    }

    @Test
    fun `test get filter by id - non-existing filter`() {
        val nonExistent = getFilterById("non_existent_filter")

        // Should return null for non-existent filter
        assertNull(nonExistent)
    }

    @Test
    fun `test filter category enum values`() {
        val categories = FilterCategory.values()

        assertEquals(3, categories.size)
        assertTrue(categories.contains(FilterCategory.FACE))
        assertTrue(categories.contains(FilterCategory.HAIR))
        assertTrue(categories.contains(FilterCategory.COMBO))
    }

    @Test
    fun `test all filters have valid properties`() {
        val allFilters = PredefinedFilters.getAllFilters()

        allFilters.forEach { filter ->
            assertTrue(filter.id.isNotEmpty())
            assertTrue(filter.name.isNotEmpty())
            assertTrue(filter.thumbnailRes.isNotEmpty())
            assertTrue(filter.defaultIntensity in 0f..1f)
        }
    }
}
