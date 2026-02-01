package com.example.nativelocal_slm_app.presentation.filters

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.example.nativelocal_slm_app.domain.model.HairAccessory
import com.example.nativelocal_slm_app.domain.model.HairStyleSelection
import com.example.nativelocal_slm_app.domain.model.LengthPreset
import com.example.nativelocal_slm_app.ui.theme.NativeLocal_SLM_AppTheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
    import org.junit.Test
import org.junit.runner.RunWith

/**
 * Instrumented tests for StyleSelectionSheet composable.
 */
@RunWith(AndroidJUnit4::class)
class StyleSelectionSheetTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private var selectedStyle: HairStyleSelection? = null
    private var styleSelectedCalled = false
    private var dismissCalled = false

    @Before
    fun setup() {
        selectedStyle = null
        styleSelectedCalled = false
        dismissCalled = false
    }

    @Test
    fun styleSelectionSheet_displaysTitle() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                StyleSelectionSheet(
                    onStyleSelected = { },
                    onDismiss = { }
                )
            }
        }

        composeTestRule.onNodeWithText("Hair Styles")
            .assertIsDisplayed()
    }

    @Test
    fun styleSelectionSheet_displaysCloseButton() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                StyleSelectionSheet(
                    onStyleSelected = { },
                    onDismiss = { dismissCalled = true }
                )
            }
        }

        composeTestRule.onNodeWithText("Close")
            .performClick()

        assertTrue(dismissCalled)
    }

    @Test
    fun styleSelectionSheet_displaysLengthSection() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                StyleSelectionSheet(
                    onStyleSelected = { },
                    onDismiss = { }
                )
            }
        }

        composeTestRule.onNodeWithText("Length")
            .assertIsDisplayed()
    }

    @Test
    fun styleSelectionSheet_displaysAllLengthPresets() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                StyleSelectionSheet(
                    onStyleSelected = { },
                    onDismiss = { }
                )
            }
        }

        LengthPreset.values().forEach { preset ->
            composeTestRule.onNodeWithText(preset.displayName)
                .assertIsDisplayed()
        }
    }

    @Test
    fun styleSelectionSheet_displaysLengthDescriptions() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                StyleSelectionSheet(
                    onStyleSelected = { },
                    onDismiss = { }
                )
            }
        }

        LengthPreset.values().forEach { preset ->
            composeTestRule.onNodeWithText(preset.description)
                .assertIsDisplayed()
        }
    }

    @Test
    fun styleSelectionSheet_clickingLengthPreset_callsOnStyleSelected() {
        val testPreset = LengthPreset.MEDIUM

        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                StyleSelectionSheet(
                    onStyleSelected = {
                        selectedStyle = it
                        styleSelectedCalled = true
                    },
                    onDismiss = { }
                )
            }
        }

        composeTestRule.onNodeWithText(testPreset.displayName)
            .performClick()

        assertTrue(styleSelectedCalled)
        assertNotNull(selectedStyle)
        assertTrue(selectedStyle is HairStyleSelection.Length)
        assertEquals(testPreset, (selectedStyle as HairStyleSelection.Length).preset)
    }

    @Test
    fun styleSelectionSheet_selectingLength_callsDismiss() {
        val testPreset = LengthPreset.SHORT

        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                StyleSelectionSheet(
                    onStyleSelected = { },
                    onDismiss = { dismissCalled = true }
                )
            }
        }

        composeTestRule.onNodeWithText(testPreset.displayName)
            .performClick()

        assertTrue(dismissCalled)
    }

    @Test
    fun styleSelectionSheet_displaysAccessoriesSection() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                StyleSelectionSheet(
                    onStyleSelected = { },
                    onDismiss = { }
                )
            }
        }

        composeTestRule.onNodeWithText("Accessories")
            .assertIsDisplayed()
    }

    @Test
    fun styleSelectionSheet_displaysAllAccessories() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                StyleSelectionSheet(
                    onStyleSelected = { },
                    onDismiss = { }
                )
            }
        }

        HairAccessory.values().forEach { accessory ->
            composeTestRule.onNodeWithText(accessory.displayName)
                .assertIsDisplayed()
        }
    }

    @Test
    fun styleSelectionSheet_clickingAccessory_callsOnStyleSelected() {
        val testAccessory = HairAccessory.HEADBAND

        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                StyleSelectionSheet(
                    onStyleSelected = {
                        selectedStyle = it
                        styleSelectedCalled = true
                    },
                    onDismiss = { }
                )
            }
        }

        composeTestRule.onNodeWithText(testAccessory.displayName)
            .performClick()

        assertTrue(styleSelectedCalled)
        assertNotNull(selectedStyle)
        assertTrue(selectedStyle is HairStyleSelection.Accessory)
        assertEquals(testAccessory, (selectedStyle as HairStyleSelection.Accessory).accessory)
    }

    @Test
    fun styleSelectionSheet_selectingAccessory_callsDismiss() {
        val testAccessory = HairAccessory.FLOWER_CROWN

        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                StyleSelectionSheet(
                    onStyleSelected = { },
                    onDismiss = { dismissCalled = true }
                )
            }
        }

        composeTestRule.onNodeWithText(testAccessory.displayName)
            .performClick()

        assertTrue(dismissCalled)
    }

    @Test
    fun styleSelectionSheet_displaysFiveLengthPresets() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                StyleSelectionSheet(
                    onStyleSelected = { },
                    onDismiss = { }
                )
            }
        }

        assertEquals(5, LengthPreset.values().size)

        LengthPreset.values().forEach { preset ->
            composeTestRule.onNodeWithText(preset.displayName)
                .assertIsDisplayed()
        }
    }

    @Test
    fun styleSelectionSheet_displaysSevenAccessories() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                StyleSelectionSheet(
                    onStyleSelected = { },
                    onDismiss = { }
                )
            }
        }

        assertEquals(7, HairAccessory.values().size)

        HairAccessory.values().forEach { accessory ->
            composeTestRule.onNodeWithText(accessory.displayName)
                .assertIsDisplayed()
        }
    }

    @Test
    fun styleSelectionSheet_clickingMultipleLengthPresets() {
        var selectedCount = 0
        val selectedStyles = mutableListOf<HairStyleSelection>()

        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                StyleSelectionSheet(
                    onStyleSelected = {
                        selectedStyles.add(it)
                        selectedCount++
                    },
                    onDismiss = { }
                )
            }
        }

        // Click on different length presets
        composeTestRule.onNodeWithText(LengthPreset.SHORT.displayName)
            .performClick()

        composeTestRule.onNodeWithText(LengthPreset.LONG.displayName)
            .performClick()

        assertEquals(2, selectedCount)
        assertEquals(2, selectedStyles.size)
        assertTrue(selectedStyles[0] is HairStyleSelection.Length)
        assertTrue(selectedStyles[1] is HairStyleSelection.Length)
    }

    @Test
    fun styleSelectionSheet_clickingMultipleAccessories() {
        var selectedCount = 0
        val selectedStyles = mutableListOf<HairStyleSelection>()

        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                StyleSelectionSheet(
                    onStyleSelected = {
                        selectedStyles.add(it)
                        selectedCount++
                    },
                    onDismiss = { }
                )
            }
        }

        // Click on different accessories
        composeTestRule.onNodeWithText(HairAccessory.HEADBAND.displayName)
            .performClick()

        composeTestRule.onNodeWithText(HairAccessory.TIARA.displayName)
            .performClick()

        assertEquals(2, selectedCount)
        assertEquals(2, selectedStyles.size)
        assertTrue(selectedStyles[0] is HairStyleSelection.Accessory)
        assertTrue(selectedStyles[1] is HairStyleSelection.Accessory)
    }

    @Test
    fun styleSelectionSheet_clickingBothLengthAndAccessory() {
        var selectedCount = 0
        val selectedStyles = mutableListOf<HairStyleSelection>()

        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                StyleSelectionSheet(
                    onStyleSelected = {
                        selectedStyles.add(it)
                        selectedCount++
                    },
                    onDismiss = { }
                )
            }
        }

        // Click on length preset
        composeTestRule.onNodeWithText(LengthPreset.MEDIUM.displayName)
            .performClick()

        // Click on accessory
        composeTestRule.onNodeWithText(HairAccessory.RIBBON.displayName)
            .performClick()

        assertEquals(2, selectedCount)
        assertTrue(selectedStyles[0] is HairStyleSelection.Length)
        assertTrue(selectedStyles[1] is HairStyleSelection.Accessory)
    }

    @Test
    fun styleSelectionSheet_displaysNoAccessoriesOption() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                StyleSelectionSheet(
                    onStyleSelected = { },
                    onDismiss = { }
                )
            }
        }

        // "No Accessory" should be displayed
        composeTestRule.onNodeWithText(HairAccessory.NONE.displayName)
            .assertIsDisplayed()
    }

    @Test
    fun styleSelectionSheet_clickingNoAccessory() {
        var selectedStyle: HairStyleSelection? = null

        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                StyleSelectionSheet(
                    onStyleSelected = { selectedStyle = it },
                    onDismiss = { }
                )
            }
        }

        composeTestRule.onNodeWithText(HairAccessory.NONE.displayName)
            .performClick()

        assertNotNull(selectedStyle)
        assertTrue(selectedStyle is HairStyleSelection.Accessory)
        assertEquals(HairAccessory.NONE, (selectedStyle as HairStyleSelection.Accessory).accessory)
    }

    @Test
    fun styleSelectionSheet_allLengthPresetDescriptions() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                StyleSelectionSheet(
                    onStyleSelected = { },
                    onDismiss = { }
                )
            }
        }

        // Verify specific descriptions
        composeTestRule.onNodeWithText("Above chin length")
            .assertIsDisplayed()
        composeTestRule.onNodeWithText("At shoulder level")
            .assertIsDisplayed()
        composeTestRule.onNodeWithText("Below shoulder, above mid-back")
            .assertIsDisplayed()
        composeTestRule.onNodeWithText("Mid-back length")
            .assertIsDisplayed()
        composeTestRule.onNodeWithText("Waist length or longer")
            .assertIsDisplayed()
    }

    @Test
    fun styleSelectionSheet_clickingCloseButton_withoutSelection() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                StyleSelectionSheet(
                    onStyleSelected = { },
                    onDismiss = { dismissCalled = true }
                )
            }
        }

        // Click close without selecting a style
        composeTestRule.onNodeWithText("Close")
            .performClick()

        assertTrue(dismissCalled)
        // Style should not be selected
        assertEquals(0, styleSelectedCalled)
    }
}
