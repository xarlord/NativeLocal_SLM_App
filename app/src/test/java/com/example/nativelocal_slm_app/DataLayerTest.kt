package com.example.nativelocal_slm_app

import android.graphics.Bitmap
import android.net.Uri
import androidx.compose.ui.graphics.Color
import com.example.nativelocal_slm_app.data.model.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue
import java.time.Instant

/**
 * Comprehensive tests for all data layer models.
 * Tests data classes, enums, and predefined filters.
 */
@RunWith(RobolectricTestRunner::class)
class DataLayerTest {

    // ========== FilterCategory Tests ==========
    @Test
    fun `test FilterCategory enum values`() {
        val categories = FilterCategory.values()
        assertEquals(3, categories.size)
        assertTrue(categories.contains(FilterCategory.FACE))
        assertTrue(categories.contains(FilterCategory.HAIR))
        assertTrue(categories.contains(FilterCategory.COMBO))
    }

    // ========== BlendMode Tests ==========
    @Test
    fun `test BlendMode enum values`() {
        val modes = BlendMode.values()
        assertEquals(10, modes.size)
        assertTrue(modes.contains(BlendMode.NORMAL))
        assertTrue(modes.contains(BlendMode.MULTIPLY))
        assertTrue(modes.contains(BlendMode.SCREEN))
        assertTrue(modes.contains(BlendMode.OVERLAY))
        assertTrue(modes.contains(BlendMode.SOFT_LIGHT))
        assertTrue(modes.contains(BlendMode.HARD_LIGHT))
        assertTrue(modes.contains(BlendMode.COLOR_DODGE))
        assertTrue(modes.contains(BlendMode.COLOR_BURN))
        assertTrue(modes.contains(BlendMode.DIFFERENCE))
        assertTrue(modes.contains(BlendMode.EXCLUSION))
    }

    // ========== FilterEffect Tests ==========
    @Test
    fun `test FilterEffect creation with defaults`() {
        val filter = FilterEffect(
            id = "test",
            name = "Test Filter",
            category = FilterCategory.FACE,
            thumbnailRes = "filters/test.png"
        )

        assertEquals("test", filter.id)
        assertEquals("Test Filter", filter.name)
        assertEquals(FilterCategory.FACE, filter.category)
        assertEquals("filters/test.png", filter.thumbnailRes)
        assertEquals(BlendMode.NORMAL, filter.blendMode)
        assertEquals(1.0f, filter.defaultIntensity)
    }

    @Test
    fun `test FilterEffect creation with custom blend mode`() {
        val filter = FilterEffect(
            id = "test",
            name = "Test Filter",
            category = FilterCategory.HAIR,
            thumbnailRes = "filters/test.png",
            blendMode = BlendMode.SCREEN
        )

        assertEquals(BlendMode.SCREEN, filter.blendMode)
    }

    @Test
    fun `test FilterEffect creation with custom intensity`() {
        val filter = FilterEffect(
            id = "test",
            name = "Test Filter",
            category = FilterCategory.COMBO,
            thumbnailRes = "filters/test.png",
            defaultIntensity = 0.7f
        )

        assertEquals(0.7f, filter.defaultIntensity)
    }

    // ========== FilterAssets Tests ==========
    @Test
    fun `test FilterAssets with all nulls`() {
        val assets = FilterAssets()

        assertEquals(null, assets.maskOverlay)
        assertEquals(null, assets.eyeOverlay)
        assertEquals(null, assets.hairOverlay)
        assertEquals(null, assets.colorOverlay)
        assertEquals(null, assets.metadata)
    }

    @Test
    fun `test FilterAssets with mask overlay`() {
        val bitmap = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)
        val assets = FilterAssets(maskOverlay = bitmap)

        assertEquals(bitmap, assets.maskOverlay)
        assertEquals(null, assets.eyeOverlay)
    }

    @Test
    fun `test FilterAssets with color overlay`() {
        val assets = FilterAssets(colorOverlay = Color.Red)

        assertEquals(Color.Red, assets.colorOverlay)
    }

    @Test
    fun `test FilterAssets with metadata`() {
        val metadata = FilterMetadata(
            author = "Test Author",
            version = "1.0",
            description = "Test filter",
            tags = listOf("test", "demo")
        )
        val assets = FilterAssets(metadata = metadata)

        assertEquals(metadata, assets.metadata)
        assertEquals("Test Author", assets.metadata?.author)
        assertEquals(2, assets.metadata?.tags?.size)
    }

    // ========== FilterMetadata Tests ==========
    @Test
    fun `test FilterMetadata with all fields`() {
        val metadata = FilterMetadata(
            author = "John Doe",
            version = "2.1.0",
            description = "A beautiful filter",
            tags = listOf("beauty", "makeup", "face")
        )

        assertEquals("John Doe", metadata.author)
        assertEquals("2.1.0", metadata.version)
        assertEquals("A beautiful filter", metadata.description)
        assertEquals(3, metadata.tags.size)
        assertTrue(metadata.tags.contains("beauty"))
    }

    @Test
    fun `test FilterMetadata with empty tags`() {
        val metadata = FilterMetadata(tags = emptyList())

        assertEquals(emptyList(), metadata.tags)
        assertEquals(0, metadata.tags.size)
    }

    // ========== PredefinedFilters Tests ==========
    @Test
    fun `test batman filter properties`() {
        assertEquals("batman", PredefinedFilters.batmanFilter.id)
        assertEquals("Batman", PredefinedFilters.batmanFilter.name)
        assertEquals(FilterCategory.FACE, PredefinedFilters.batmanFilter.category)
        assertEquals("filters/face/batman/thumbnail.png", PredefinedFilters.batmanFilter.thumbnailRes)
        assertEquals(BlendMode.NORMAL, PredefinedFilters.batmanFilter.blendMode)
    }

    @Test
    fun `test joker filter properties`() {
        assertEquals("joker", PredefinedFilters.jokerFilter.id)
        assertEquals("Joker", PredefinedFilters.jokerFilter.name)
        assertEquals(FilterCategory.FACE, PredefinedFilters.jokerFilter.category)
    }

    @Test
    fun `test neon glow filter uses screen blend mode`() {
        assertEquals(BlendMode.SCREEN, PredefinedFilters.neonGlowFilter.blendMode)
    }

    @Test
    fun `test cyberpunk filter uses overlay blend mode`() {
        assertEquals(BlendMode.OVERLAY, PredefinedFilters.cyberpunkFilter.blendMode)
    }

    @Test
    fun `test getAllFilters returns all predefined filters`() {
        val allFilters = PredefinedFilters.getAllFilters()

        assertEquals(10, allFilters.size)
        assertTrue(allFilters.any { it.id == "batman" })
        assertTrue(allFilters.any { it.id == "joker" })
        assertTrue(allFilters.any { it.id == "wonder_woman" })
    }

    @Test
    fun `test getFiltersByCategory for FACE`() {
        val faceFilters = PredefinedFilters.getFiltersByCategory(FilterCategory.FACE)

        assertEquals(4, faceFilters.size)
        assertTrue(faceFilters.all { it.category == FilterCategory.FACE })
        assertTrue(faceFilters.any { it.id == "batman" })
        assertTrue(faceFilters.any { it.id == "skeleton" })
        assertFalse(faceFilters.any { it.id == "punk_mohawk" })
    }

    @Test
    fun `test getFiltersByCategory for HAIR`() {
        val hairFilters = PredefinedFilters.getFiltersByCategory(FilterCategory.HAIR)

        assertEquals(3, hairFilters.size)
        assertTrue(hairFilters.all { it.category == FilterCategory.HAIR })
        assertTrue(hairFilters.any { it.id == "punk_mohawk" })
        assertTrue(hairFilters.any { it.id == "neon_glow" })
    }

    @Test
    fun `test getFiltersByCategory for COMBO`() {
        val comboFilters = PredefinedFilters.getFiltersByCategory(FilterCategory.COMBO)

        assertEquals(3, comboFilters.size)
        assertTrue(comboFilters.all { it.category == FilterCategory.COMBO })
        assertTrue(comboFilters.any { it.id == "wonder_woman" })
        assertTrue(comboFilters.any { it.id == "cyberpunk" })
    }

    @Test
    fun `test getFilterById with existing filter`() {
        val batman = PredefinedFilters.getFilterById("batman")

        assertNotNull(batman)
        assertEquals("batman", batman?.id)
        assertEquals("Batman", batman?.name)
    }

    @Test
    fun `test getFilterById with non-existing filter`() {
        val nonExistent = PredefinedFilters.getFilterById("non_existent_filter")

        assertEquals(null, nonExistent)
    }

    @Test
    fun `test getFilterById for each predefined filter`() {
        val filterIds = listOf(
            "batman", "joker", "skeleton", "tiger_face",
            "punk_mohawk", "neon_glow", "fire_hair",
            "wonder_woman", "harley_quinn", "cyberpunk"
        )

        filterIds.forEach { id ->
            val filter = PredefinedFilters.getFilterById(id)
            assertNotNull(filter, "Filter with id $id should exist")
            assertEquals(id, filter?.id)
        }
    }

    // ========== SavedLook Tests ==========
    @Test
    fun `test SavedLook creation`() {
        val now = Instant.now()
        val savedLook = SavedLook(
            id = "look_123",
            timestamp = now,
            originalImage = Uri.parse("file:///test/original.jpg"),
            resultImage = Uri.parse("file:///test/result.jpg"),
            appliedFilters = listOf("batman", "joker")
        )

        assertEquals("look_123", savedLook.id)
        assertEquals(now, savedLook.timestamp)
        assertEquals("file:///test/original.jpg", savedLook.originalImage.toString())
        assertEquals("file:///test/result.jpg", savedLook.resultImage.toString())
        assertEquals(2, savedLook.appliedFilters.size)
    }

    @Test
    fun `test SavedLook getFormattedTimestamp - just now`() {
        val now = Instant.now()
        val savedLook = SavedLook(
            id = "test",
            timestamp = now,
            originalImage = Uri.EMPTY,
            resultImage = Uri.EMPTY,
            appliedFilters = emptyList()
        )

        assertEquals("Just now", savedLook.getFormattedTimestamp())
    }

    @Test
    fun `test SavedLook getFormattedTimestamp - minutes ago`() {
        val now = Instant.now()
        val fiveMinutesAgo = now.minusSeconds(5 * 60)
        val savedLook = SavedLook(
            id = "test",
            timestamp = fiveMinutesAgo,
            originalImage = Uri.EMPTY,
            resultImage = Uri.EMPTY,
            appliedFilters = emptyList()
        )

        assertEquals("5m ago", savedLook.getFormattedTimestamp())
    }

    @Test
    fun `test SavedLook getFormattedTimestamp - hours ago`() {
        val now = Instant.now()
        val twoHoursAgo = now.minusSeconds(2 * 3600)
        val savedLook = SavedLook(
            id = "test",
            timestamp = twoHoursAgo,
            originalImage = Uri.EMPTY,
            resultImage = Uri.EMPTY,
            appliedFilters = emptyList()
        )

        assertEquals("2h ago", savedLook.getFormattedTimestamp())
    }

    @Test
    fun `test SavedLook getFormattedTimestamp - days ago`() {
        val now = Instant.now()
        val threeDaysAgo = now.minusSeconds(3 * 86400)
        val savedLook = SavedLook(
            id = "test",
            timestamp = threeDaysAgo,
            originalImage = Uri.EMPTY,
            resultImage = Uri.EMPTY,
            appliedFilters = emptyList()
        )

        assertEquals("3d ago", savedLook.getFormattedTimestamp())
    }

    @Test
    fun `test SavedLook getFormattedTimestamp - date format`() {
        val now = Instant.now()
        val twoWeeksAgo = now.minusSeconds(14 * 86400)
        val savedLook = SavedLook(
            id = "test",
            timestamp = twoWeeksAgo,
            originalImage = Uri.EMPTY,
            resultImage = Uri.EMPTY,
            appliedFilters = emptyList()
        )

        val formatted = savedLook.getFormattedTimestamp()
        assertTrue(formatted.matches(Regex("\\d{4}-\\d{2}-\\d{2}")))
    }

    @Test
    fun `test SavedLook getFilterNames with known filters`() {
        val savedLook = SavedLook(
            id = "test",
            timestamp = Instant.now(),
            originalImage = Uri.EMPTY,
            resultImage = Uri.EMPTY,
            appliedFilters = listOf("batman", "joker", "cyberpunk")
        )

        val names = savedLook.getFilterNames()
        assertEquals(3, names.size)
        assertEquals("Batman", names[0])
        assertEquals("Joker", names[1])
        assertEquals("Cyberpunk", names[2])
    }

    @Test
    fun `test SavedLook getFilterNames with unknown filter`() {
        val savedLook = SavedLook(
            id = "test",
            timestamp = Instant.now(),
            originalImage = Uri.EMPTY,
            resultImage = Uri.EMPTY,
            appliedFilters = listOf("unknown_filter")
        )

        val names = savedLook.getFilterNames()
        assertEquals(1, names.size)
        assertEquals("unknown_filter", names[0])
    }

    @Test
    fun `test SavedLook getFilterNames with mixed filters`() {
        val savedLook = SavedLook(
            id = "test",
            timestamp = Instant.now(),
            originalImage = Uri.EMPTY,
            resultImage = Uri.EMPTY,
            appliedFilters = listOf("batman", "unknown", "joker")
        )

        val names = savedLook.getFilterNames()
        assertEquals(3, names.size)
        assertEquals("Batman", names[0])
        assertEquals("unknown", names[1])
        assertEquals("Joker", names[2])
    }

    @Test
    fun `test SavedLook getFilterNames with empty list`() {
        val savedLook = SavedLook(
            id = "test",
            timestamp = Instant.now(),
            originalImage = Uri.EMPTY,
            resultImage = Uri.EMPTY,
            appliedFilters = emptyList()
        )

        val names = savedLook.getFilterNames()
        assertEquals(0, names.size)
    }

    // ========== FilterEffect Edge Cases ==========
    @Test
    fun `test FilterEffect with minimum intensity`() {
        val filter = FilterEffect(
            id = "test",
            name = "Test",
            category = FilterCategory.FACE,
            thumbnailRes = "test.png",
            defaultIntensity = 0f
        )

        assertEquals(0f, filter.defaultIntensity)
    }

    @Test
    fun `test FilterEffect with maximum intensity`() {
        val filter = FilterEffect(
            id = "test",
            name = "Test",
            category = FilterCategory.FACE,
            thumbnailRes = "test.png",
            defaultIntensity = 1f
        )

        assertEquals(1f, filter.defaultIntensity)
    }

    @Test
    fun `test all predefined filters have valid properties`() {
        val allFilters = PredefinedFilters.getAllFilters()

        allFilters.forEach { filter ->
            assertTrue(filter.id.isNotEmpty(), "Filter id should not be empty")
            assertTrue(filter.name.isNotEmpty(), "Filter name should not be empty")
            assertTrue(filter.thumbnailRes.isNotEmpty(), "Filter thumbnailRes should not be empty")
            assertTrue(filter.defaultIntensity in 0f..1f, "Filter intensity should be between 0 and 1")
        }
    }

    @Test
    fun `test all filter IDs are unique`() {
        val allFilters = PredefinedFilters.getAllFilters()
        val ids = allFilters.map { it.id }
        val uniqueIds = ids.toSet()

        assertEquals(ids.size, uniqueIds.size, "All filter IDs should be unique")
    }

    // ========== Data Class Methods Coverage ==========

    @Test
    fun `test FilterEffect toString equals hashCode`() {
        val filter1 = FilterEffect(
            id = "test",
            name = "Test Filter",
            category = FilterCategory.FACE,
            thumbnailRes = "filters/test.png",
            blendMode = BlendMode.SCREEN,
            defaultIntensity = 0.8f
        )

        // Test toString()
        val str = filter1.toString()
        assertTrue(str.contains("FilterEffect"))
        assertTrue(str.contains("test"))

        // Test equals()
        val filter2 = FilterEffect(
            id = "test",
            name = "Test Filter",
            category = FilterCategory.FACE,
            thumbnailRes = "filters/test.png",
            blendMode = BlendMode.SCREEN,
            defaultIntensity = 0.8f
        )
        assertEquals(filter1, filter2)
        assertEquals(filter1.hashCode(), filter2.hashCode())

        // Test inequality
        val filter3 = filter1.copy(defaultIntensity = 0.5f)
        assert(filter1 != filter3)
    }

    @Test
    fun `test FilterEffect copy method`() {
        val filter1 = FilterEffect(
            id = "original",
            name = "Original",
            category = FilterCategory.HAIR,
            thumbnailRes = "filters/original.png"
        )

        val filter2 = filter1.copy(
            id = "copy",
            name = "Copy",
            defaultIntensity = 0.6f
        )

        assertEquals("original", filter1.id)
        assertEquals("copy", filter2.id)
        assertEquals("Copy", filter2.name)
        assertEquals(FilterCategory.HAIR, filter2.category)
        assertEquals(0.6f, filter2.defaultIntensity)
    }

    @Test
    fun `test FilterCategory enum methods`() {
        val categories = FilterCategory.values()
        assertEquals(3, categories.size)

        // Test additional enum methods
        assertEquals("FACE", FilterCategory.FACE.name)
        assertEquals(0, FilterCategory.FACE.ordinal)
        assertEquals(FilterCategory.HAIR, FilterCategory.valueOf("HAIR"))
    }

    @Test
    fun `test BlendMode enum methods`() {
        val modes = BlendMode.values()
        assertEquals(10, modes.size)

        // Test additional enum methods
        assertEquals("NORMAL", BlendMode.NORMAL.name)
        assertEquals(0, BlendMode.NORMAL.ordinal)
        assertEquals(BlendMode.SCREEN, BlendMode.valueOf("SCREEN"))
    }

    @Test
    fun `test FilterAssets toString equals hashCode`() {
        val bitmap = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)
        val assets1 = FilterAssets(
            maskOverlay = bitmap,
            eyeOverlay = null,
            hairOverlay = null,
            colorOverlay = Color.Red,
            metadata = FilterMetadata(author = "Test", version = "1.0")
        )

        // Test toString()
        val str = assets1.toString()
        assertTrue(str.contains("FilterAssets"))

        // Test equals()
        val assets2 = FilterAssets(
            maskOverlay = bitmap,
            eyeOverlay = null,
            hairOverlay = null,
            colorOverlay = Color.Red,
            metadata = FilterMetadata(author = "Test", version = "1.0")
        )
        assertEquals(assets1, assets2)
        assertEquals(assets1.hashCode(), assets2.hashCode())

        bitmap.recycle()
    }

    @Test
    fun `test FilterMetadata toString equals hashCode`() {
        val metadata1 = FilterMetadata(
            author = "Author1",
            version = "2.0",
            description = "Test",
            tags = listOf("tag1", "tag2")
        )

        // Test toString()
        val str = metadata1.toString()
        assertTrue(str.contains("FilterMetadata"))

        // Test equals()
        val metadata2 = FilterMetadata(
            author = "Author1",
            version = "2.0",
            description = "Test",
            tags = listOf("tag1", "tag2")
        )
        assertEquals(metadata1, metadata2)
        assertEquals(metadata1.hashCode(), metadata2.hashCode())

        // Test inequality
        val metadata3 = metadata1.copy(author = "Author2")
        assert(metadata1 != metadata3)
    }

    @Test
    fun `test SavedLook toString equals hashCode copy`() {
        val now = Instant.now()
        val look1 = SavedLook(
            id = "look_1",
            timestamp = now,
            originalImage = Uri.parse("file:///test/original.jpg"),
            resultImage = Uri.parse("file:///test/result.jpg"),
            appliedFilters = listOf("batman", "joker")
        )

        // Test toString()
        val str = look1.toString()
        assertTrue(str.contains("SavedLook"))

        // Test equals()
        val look2 = SavedLook(
            id = "look_1",
            timestamp = now,
            originalImage = Uri.parse("file:///test/original.jpg"),
            resultImage = Uri.parse("file:///test/result.jpg"),
            appliedFilters = listOf("batman", "joker")
        )
        assertEquals(look1, look2)
        assertEquals(look1.hashCode(), look2.hashCode())

        // Test copy()
        val look3 = look1.copy(id = "look_2")
        assertEquals("look_2", look3.id)
        assertEquals(now, look3.timestamp)

        // Test methods
        assertEquals("Batman", look1.getFilterNames()[0])
        assertEquals("Joker", look1.getFilterNames()[1])
    }

    @Test
    fun `test SavedLook getFormattedTimestamp edge cases`() {
        val now = Instant.now()

        // Test 59 seconds ago (should show "Just now")
        val look1 = SavedLook(
            id = "test1",
            timestamp = now.minusSeconds(59),
            originalImage = Uri.EMPTY,
            resultImage = Uri.EMPTY,
            appliedFilters = emptyList()
        )
        assertEquals("Just now", look1.getFormattedTimestamp())

        // Test 60 seconds ago (should show "1m ago")
        val look2 = SavedLook(
            id = "test2",
            timestamp = now.minusSeconds(60),
            originalImage = Uri.EMPTY,
            resultImage = Uri.EMPTY,
            appliedFilters = emptyList()
        )
        assertEquals("1m ago", look2.getFormattedTimestamp())

        // Test 3599 seconds ago (should show "59m ago")
        val look3 = SavedLook(
            id = "test3",
            timestamp = now.minusSeconds(3599),
            originalImage = Uri.EMPTY,
            resultImage = Uri.EMPTY,
            appliedFilters = emptyList()
        )
        assertEquals("59m ago", look3.getFormattedTimestamp())

        // Test 3600 seconds ago (should show "1h ago")
        val look4 = SavedLook(
            id = "test4",
            timestamp = now.minusSeconds(3600),
            originalImage = Uri.EMPTY,
            resultImage = Uri.EMPTY,
            appliedFilters = emptyList()
        )
        assertEquals("1h ago", look4.getFormattedTimestamp())

        // Test 86399 seconds ago (should show "23h ago")
        val look5 = SavedLook(
            id = "test5",
            timestamp = now.minusSeconds(86399),
            originalImage = Uri.EMPTY,
            resultImage = Uri.EMPTY,
            appliedFilters = emptyList()
        )
        assertEquals("23h ago", look5.getFormattedTimestamp())

        // Test 86400 seconds ago (should show "1d ago")
        val look6 = SavedLook(
            id = "test6",
            timestamp = now.minusSeconds(86400),
            originalImage = Uri.EMPTY,
            resultImage = Uri.EMPTY,
            appliedFilters = emptyList()
        )
        assertEquals("1d ago", look6.getFormattedTimestamp())

        // Test 604799 seconds ago (should show "6d ago")
        val look7 = SavedLook(
            id = "test7",
            timestamp = now.minusSeconds(604799),
            originalImage = Uri.EMPTY,
            resultImage = Uri.EMPTY,
            appliedFilters = emptyList()
        )
        assertEquals("6d ago", look7.getFormattedTimestamp())

        // Test 604800 seconds ago (should show date format)
        val look8 = SavedLook(
            id = "test8",
            timestamp = now.minusSeconds(604800),
            originalImage = Uri.EMPTY,
            resultImage = Uri.EMPTY,
            appliedFilters = emptyList()
        )
        val formatted = look8.getFormattedTimestamp()
        assertTrue(formatted.matches(Regex("\\d{4}-\\d{2}-\\d{2}")))
    }

    @Test
    fun `test SavedLook getFilterNames with all predefined filters`() {
        val allFilters = PredefinedFilters.getAllFilters()
        val filterIds = allFilters.map { it.id }

        val look = SavedLook(
            id = "test",
            timestamp = Instant.now(),
            originalImage = Uri.EMPTY,
            resultImage = Uri.EMPTY,
            appliedFilters = filterIds
        )

        val names = look.getFilterNames()
        assertEquals(10, names.size)
        assertEquals("Batman", names[0])
        assertEquals("Joker", names[1])
        assertEquals("Skeleton", names[2])
        assertEquals("Tiger Face", names[3])
        assertEquals("Punk Mohawk", names[4])
        assertEquals("Neon Glow", names[5])
        assertEquals("Fire Hair", names[6])
        assertEquals("Wonder Woman", names[7])
        assertEquals("Harley Quinn", names[8])
        assertEquals("Cyberpunk", names[9])
    }

    @Test
    fun `test PredefinedFilters getFiltersByCategory returns correct filters`() {
        val faceFilters = PredefinedFilters.getFiltersByCategory(FilterCategory.FACE)
        assertEquals(4, faceFilters.size)
        assertTrue(faceFilters.all { it.category == FilterCategory.FACE })

        val hairFilters = PredefinedFilters.getFiltersByCategory(FilterCategory.HAIR)
        assertEquals(3, hairFilters.size)
        assertTrue(hairFilters.all { it.category == FilterCategory.HAIR })

        val comboFilters = PredefinedFilters.getFiltersByCategory(FilterCategory.COMBO)
        assertEquals(3, comboFilters.size)
        assertTrue(comboFilters.all { it.category == FilterCategory.COMBO })
    }

    @Test
    fun `test PredefinedFilters getFilterById returns correct filters`() {
        val batman = PredefinedFilters.getFilterById("batman")
        assertNotNull(batman)
        assertEquals("Batman", batman?.name)
        assertEquals(FilterCategory.FACE, batman?.category)

        val joker = PredefinedFilters.getFilterById("joker")
        assertNotNull(joker)
        assertEquals("Joker", joker?.name)

        val nonExistent = PredefinedFilters.getFilterById("non_existent")
        assertNull(nonExistent)
    }

    @Test
    fun `test PredefinedFilters getAllFilters returns consistent list`() {
        val filters1 = PredefinedFilters.getAllFilters()
        val filters2 = PredefinedFilters.getAllFilters()

        assertEquals(filters1.size, filters2.size)
        assertEquals(filters1, filters2)
    }

    @Test
    fun `test FilterEffect componentN methods`() {
        val filter = FilterEffect(
            id = "test_id",
            name = "Test Name",
            category = FilterCategory.HAIR,
            thumbnailRes = "test/path.png",
            blendMode = BlendMode.OVERLAY,
            defaultIntensity = 0.75f
        )

        // Data class componentN() methods are generated
        // We can access them via destructuring which exercises them
        val (id, name, category, thumbnail, blendMode, intensity) = filter
        assertEquals("test_id", id)
        assertEquals("Test Name", name)
        assertEquals(FilterCategory.HAIR, category)
        assertEquals("test/path.png", thumbnail)
        assertEquals(BlendMode.OVERLAY, blendMode)
        assertEquals(0.75f, intensity)
    }

    @Test
    fun `test SavedLook componentN methods`() {
        val now = Instant.now()
        val look = SavedLook(
            id = "look_id",
            timestamp = now,
            originalImage = Uri.parse("file://orig.jpg"),
            resultImage = Uri.parse("file://result.jpg"),
            appliedFilters = listOf("batman")
        )

        // Test destructuring which exercises componentN() methods
        val (id, timestamp, orig, result, filters) = look
        assertEquals("look_id", id)
        assertEquals(now, timestamp)
        assertEquals("file://orig.jpg", orig.toString())
        assertEquals("file://result.jpg", result.toString())
        assertEquals(1, filters.size)
    }

    @Test
    fun `test FilterMetadata componentN methods`() {
        val metadata = FilterMetadata(
            author = "Author",
            version = "1.0",
            description = "Description",
            tags = listOf("tag1", "tag2", "tag3")
        )

        // Test destructuring
        val (author, version, description, tags) = metadata
        assertEquals("Author", author)
        assertEquals("1.0", version)
        assertEquals("Description", description)
        assertEquals(3, tags.size)
    }
}
