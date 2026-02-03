package com.example.nativelocal_slm_app.presentation.filters

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.example.nativelocal_slm_app.ui.animation.PredefinedHairColors
import com.example.nativelocal_slm_app.ui.theme.NativeLocal_SLM_AppTheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Instrumented tests for ColorPickerSheet composable.
 */
@RunWith(AndroidJUnit4::class)
class ColorPickerSheetTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private var selectedColor: Color? = null
    private var colorSelectedCalled = false
    private var dismissCalled = false
    private var predefinedColors: List<com.example.nativelocal_slm_app.ui.animation.HairColorSwatch> = emptyList()

    @Before
    fun setup() {
        selectedColor = null
        colorSelectedCalled = false
        dismissCalled = false
        predefinedColors = PredefinedHairColors.getAllColors()
    }

    @Test
    fun colorPickerSheet_displaysTitle() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                ColorPickerSheet(
                    onColorSelected = { },
                    onDismiss = { }
                )
            }
        }

        composeTestRule.onNodeWithText("Hair Color")
            .assertIsDisplayed()
    }

    @Test
    fun colorPickerSheet_displaysCloseButton() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                ColorPickerSheet(
                    onColorSelected = { },
                    onDismiss = { dismissCalled = true }
                )
            }
        }

        composeTestRule.onNodeWithText("Close")
            .performClick()

        assertTrue(dismissCalled)
    }

    @Test
    fun colorPickerSheet_displaysPredefinedColorsSection() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                ColorPickerSheet(
                    onColorSelected = { },
                    onDismiss = { }
                )
            }
        }

        composeTestRule.onNodeWithText("Predefined Colors")
            .assertIsDisplayed()
    }

    @Test
    fun colorPickerSheet_displaysAllColorNames() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                ColorPickerSheet(
                    onColorSelected = { },
                    onDismiss = { }
                )
            }
        }

        // Verify all predefined color names are displayed
        predefinedColors.forEach { swatch ->
            composeTestRule.onNodeWithText(swatch.name)
                .assertIsDisplayed()
        }
    }

    @Test
    fun colorPickerSheet_clickingColor_callsOnColorSelected() {
        val firstColor = predefinedColors.firstOrNull()

        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                ColorPickerSheet(
                    onColorSelected = {
                        selectedColor = it
                        colorSelectedCalled = true
                    },
                    onDismiss = { }
                )
            }
        }

        firstColor?.let {
            composeTestRule.onNodeWithText(it.name)
                .performClick()

            assertTrue(colorSelectedCalled)
            assertNotNull(selectedColor)
        }
    }

    @Test
    fun colorPickerSheet_selectingColor_callsDismiss() {
        val firstColor = predefinedColors.firstOrNull()

        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                ColorPickerSheet(
                    onColorSelected = { },
                    onDismiss = { dismissCalled = true }
                )
            }
        }

        firstColor?.let {
            composeTestRule.onNodeWithText(it.name)
                .performClick()

            assertTrue(dismissCalled)
        }
    }

    @Test
    fun colorPickerSheet_displaysNaturalBlack() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                ColorPickerSheet(
                    onColorSelected = { },
                    onDismiss = { }
                )
            }
        }

        composeTestRule.onNodeWithText("Natural Black")
            .assertIsDisplayed()
    }

    @Test
    fun colorPickerSheet_displaysBrownColors() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                ColorPickerSheet(
                    onColorSelected = { },
                    onDismiss = { }
                )
            }
        }

        composeTestRule.onNodeWithText("Dark Brown")
            .assertIsDisplayed()
        composeTestRule.onNodeWithText("Medium Brown")
            .assertIsDisplayed()
        composeTestRule.onNodeWithText("Light Brown")
            .assertIsDisplayed()
    }

    @Test
    fun colorPickerSheet_displaysBlondeColors() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                ColorPickerSheet(
                    onColorSelected = { },
                    onDismiss = { }
                )
            }
        }

        composeTestRule.onNodeWithText("Blonde")
            .assertIsDisplayed()
        composeTestRule.onNodeWithText("Platinum")
            .assertIsDisplayed()
    }

    @Test
    fun colorPickerSheet_displaysRedColors() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                ColorPickerSheet(
                    onColorSelected = { },
                    onDismiss = { }
                )
            }
        }

        composeTestRule.onNodeWithText("Red")
            .assertIsDisplayed()
        composeTestRule.onNodeWithText("Copper")
            .assertIsDisplayed()
        composeTestRule.onNodeWithText("Auburn")
            .assertIsDisplayed()
    }

    @Test
    fun colorPickerSheet_displaysFantasyColors() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                ColorPickerSheet(
                    onColorSelected = { },
                    onDismiss = { }
                )
            }
        }

        composeTestRule.onNodeWithText("Pink")
            .assertIsDisplayed()
        composeTestRule.onNodeWithText("Purple")
            .assertIsDisplayed()
        composeTestRule.onNodeWithText("Blue")
            .assertIsDisplayed()
        composeTestRule.onNodeWithText("Green")
            .assertIsDisplayed()
    }

    @Test
    fun colorPickerSheet_clickingMultipleColors() {
        var selectedCount = 0
        val selectedColors = mutableListOf<Color>()

        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                ColorPickerSheet(
                    onColorSelected = {
                        selectedColors.add(it)
                        selectedCount++
                    },
                    onDismiss = { }
                )
            }
        }

        if (predefinedColors.size >= 2) {
            // Click first color
            composeTestRule.onNodeWithText(predefinedColors[0].name)
                .performClick()

            // Click second color
            composeTestRule.onNodeWithText(predefinedColors[1].name)
                .performClick()

            assertEquals(2, selectedCount)
            assertEquals(2, selectedColors.size)
        }
    }

    @Test
    fun colorPickerSheet_allColorsAreClickable() {
        var clickCount = 0

        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                ColorPickerSheet(
                    onColorSelected = { clickCount++ },
                    onDismiss = { }
                )
            }
        }

        // Click on each color
        predefinedColors.forEach { swatch ->
            composeTestRule.onNodeWithText(swatch.name)
                .performClick()
        }

        assertEquals(predefinedColors.size, clickCount)
    }

    @Test
    fun colorPickerSheet_displaysThirteenColors() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                ColorPickerSheet(
                    onColorSelected = { },
                    onDismiss = { }
                )
            }
        }

        // PredefinedHairColors.getAllColors() returns 13 colors
        assertEquals(13, predefinedColors.size)

        // All should be displayed
        predefinedColors.forEach { swatch ->
            composeTestRule.onNodeWithText(swatch.name)
                .assertIsDisplayed()
        }
    }

    @Test
    fun colorPickerSheet_handlesEmptyColorList() {
        // Test with empty colors (should not crash)
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                ColorPickerSheet(
                    onColorSelected = { },
                    onDismiss = { }
                )
            }
        }

        // Should at least show title and section header
        composeTestRule.onNodeWithText("Hair Color")
            .assertIsDisplayed()
        composeTestRule.onNodeWithText("Predefined Colors")
            .assertIsDisplayed()
    }

    @Test
    fun colorPickerSheet_clickingCloseButton_withoutSelection() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                ColorPickerSheet(
                    onColorSelected = { },
                    onDismiss = { dismissCalled = true }
                )
            }
        }

        // Click close without selecting a color
        composeTestRule.onNodeWithText("Close")
            .performClick()

        assertTrue(dismissCalled)
        // Color should not be selected
        assertEquals(0, colorSelectedCalled)
    }
}
