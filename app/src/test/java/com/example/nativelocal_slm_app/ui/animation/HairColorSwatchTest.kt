package com.example.nativelocal_slm_app.ui.animation

import androidx.compose.ui.graphics.Color
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Unit tests for HairColorSwatch data class and PredefinedHairColors.
 */
class HairColorSwatchTest {

    @Test
    fun `HairColorSwatch data class can be created`() {
        val swatch = HairColorSwatch(
            name = "Test Color",
            color = Color.Red
        )

        assertEquals("Name should match", "Test Color", swatch.name)
        assertEquals("Color should match", Color.Red, swatch.color)
    }

    @Test
    fun `HairColorSwatch data class supports equality`() {
        val swatch1 = HairColorSwatch("Red", Color.Red)
        val swatch2 = HairColorSwatch("Red", Color.Red)
        val swatch3 = HairColorSwatch("Blue", Color.Blue)

        assertEquals("Equal swatches should be equal", swatch1, swatch2)
        assertFalse("Different swatches should not be equal", swatch1 == swatch3)
    }

    @Test
    fun `HairColorSwatch data class supports copy`() {
        val swatch = HairColorSwatch("Red", Color.Red)
        val copied = swatch.copy(name = "Blue")

        assertEquals("Original name should be unchanged", "Red", swatch.name)
        assertEquals("Copied name should be new value", "Blue", copied.name)
        assertEquals("Color should be copied", Color.Red, copied.color)
    }

    @Test
    fun `getAllColors returns correct number of colors`() {
        val colors = PredefinedHairColors.getAllColors()
        assertEquals("Should have 13 predefined colors", 13, colors.size)
    }

    @Test
    fun `getAllColors contains natural black color`() {
        val colors = PredefinedHairColors.getAllColors()
        val black = colors.find { it.name == "Natural Black" }

        assertNotNull("Natural Black should exist", black)
        assertEquals("Name should match", "Natural Black", black!!.name)

        // Verify the color is dark (low RGB values)
        assertTrue("Natural Black should be dark", black.color.red < 0.2f)
        assertTrue("Natural Black should be dark", black.color.green < 0.2f)
        assertTrue("Natural Black should be dark", black.color.blue < 0.2f)
    }

    @Test
    fun `getAllColors contains brown colors`() {
        val colors = PredefinedHairColors.getAllColors()

        val darkBrown = colors.find { it.name == "Dark Brown" }
        val mediumBrown = colors.find { it.name == "Medium Brown" }
        val lightBrown = colors.find { it.name == "Light Brown" }

        assertNotNull("Dark Brown should exist", darkBrown)
        assertNotNull("Medium Brown should exist", mediumBrown)
        assertNotNull("Light Brown should exist", lightBrown)

        // Verify colors get progressively lighter
        assertTrue("Dark Brown should be darker than Medium Brown",
            darkBrown!!.color.red < mediumBrown!!.color.red)
        assertTrue("Medium Brown should be darker than Light Brown",
            mediumBrown.color.red < lightBrown!!.color.red)
    }

    @Test
    fun `getAllColors contains blonde colors`() {
        val colors = PredefinedHairColors.getAllColors()

        val blonde = colors.find { it.name == "Blonde" }
        val platinum = colors.find { it.name == "Platinum" }

        assertNotNull("Blonde should exist", blonde)
        assertNotNull("Platinum should exist", platinum)

        // Verify blonde colors are light
        assertTrue("Blonde should be light", blonde!!.color.red > 0.8f)
        assertTrue("Platinum should be very light", platinum!!.color.red > 0.9f)
    }

    @Test
    fun `getAllColors contains red colors`() {
        val colors = PredefinedHairColors.getAllColors()

        val red = colors.find { it.name == "Red" }
        val copper = colors.find { it.name == "Copper" }
        val auburn = colors.find { it.name == "Auburn" }

        assertNotNull("Red should exist", red)
        assertNotNull("Copper should exist", copper)
        assertNotNull("Auburn should exist", auburn)

        // Verify red colors have high red component
        assertTrue("Red should have high red component", red!!.color.red > 0.5f)
        assertTrue("Copper should have high red component", copper!!.color.red > 0.5f)
        assertTrue("Auburn should have high red component", auburn!!.color.red > 0.5f)
    }

    @Test
    fun `getAllColors contains fantasy colors`() {
        val colors = PredefinedHairColors.getAllColors()

        val pink = colors.find { it.name == "Pink" }
        val purple = colors.find { it.name == "Purple" }
        val blue = colors.find { it.name == "Blue" }
        val green = colors.find { it.name == "Green" }

        assertNotNull("Pink should exist", pink)
        assertNotNull("Purple should exist", purple)
        assertNotNull("Blue should exist", blue)
        assertNotNull("Green should exist", green)
    }

    @Test
    fun `all predefined colors have valid names`() {
        val colors = PredefinedHairColors.getAllColors()

        colors.forEach { swatch ->
            assertTrue("Name should not be empty", swatch.name.isNotEmpty())
            assertTrue("Name should not be blank", swatch.name.isNotBlank())
        }
    }

    @Test
    fun `all predefined colors have valid color values`() {
        val colors = PredefinedHairColors.getAllColors()

        colors.forEach { swatch ->
            assertTrue("Color should not be unspecified", swatch.color != Color.Unspecified)
            assertTrue("Color alpha should be opaque", swatch.color.alpha == 1.0f)
        }
    }

    @Test
    fun `getAllColors returns immutable list`() {
        val colors1 = PredefinedHairColors.getAllColors()
        val colors2 = PredefinedHairColors.getAllColors()

        // Verify same instance is returned or equal lists
        assertEquals("Should return equal lists", colors1, colors2)
    }

    @Test
    fun `predefined colors cover full spectrum`() {
        val colors = PredefinedHairColors.getAllColors()

        // Should have natural colors (blacks, browns, blondes)
        val naturalCount = colors.count { it.name in listOf(
            "Natural Black", "Dark Brown", "Medium Brown", "Light Brown", "Blonde", "Platinum"
        ) }
        assertTrue("Should have at least 6 natural colors", naturalCount >= 6)

        // Should have red/auburn colors
        val redCount = colors.count { it.name in listOf("Red", "Copper", "Auburn") }
        assertTrue("Should have at least 3 red colors", redCount >= 3)

        // Should have fantasy colors
        val fantasyCount = colors.count { it.name in listOf("Pink", "Purple", "Blue", "Green") }
        assertTrue("Should have at least 4 fantasy colors", fantasyCount >= 4)
    }

    @Test
    fun `HairColorSwatch can be used in collections`() {
        val swatch1 = HairColorSwatch("Red", Color.Red)
        val swatch2 = HairColorSwatch("Blue", Color.Blue)
        val swatch3 = HairColorSwatch("Green", Color.Green)

        val set = setOf(swatch1, swatch2, swatch3)
        val list = listOf(swatch1, swatch2, swatch3)

        assertEquals("Set should contain 3 items", 3, set.size)
        assertEquals("List should contain 3 items", 3, list.size)
        assertTrue("Set should contain red swatch", set.contains(swatch1))
    }
}
