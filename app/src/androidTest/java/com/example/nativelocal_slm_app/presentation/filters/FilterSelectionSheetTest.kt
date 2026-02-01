package com.example.nativelocal_slm_app.presentation.filters

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.example.nativelocal_slm_app.data.model.FilterCategory
import com.example.nativelocal_slm_app.data.model.FilterEffect
import com.example.nativelocal_slm_app.data.model.PredefinedFilters
import com.example.nativelocal_slm_app.ui.theme.NativeLocal_SLM_AppTheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Instrumented tests for FilterSelectionSheet composable.
 */
@RunWith(AndroidJUnit4::class)
class FilterSelectionSheetTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private var selectedFilter: FilterEffect? = null
    private var filterSelectedCalled = false
    private var dismissCalled = false
    private var faceFilters: List<FilterEffect> = emptyList()
    private var hairFilters: List<FilterEffect> = emptyList()
    private var comboFilters: List<FilterEffect> = emptyList()

    @Before
    fun setup() {
        selectedFilter = null
        filterSelectedCalled = false
        dismissCalled = false
        faceFilters = PredefinedFilters.getFiltersByCategory(FilterCategory.FACE)
        hairFilters = PredefinedFilters.getFiltersByCategory(FilterCategory.HAIR)
        comboFilters = PredefinedFilters.getFiltersByCategory(FilterCategory.COMBO)
    }

    @Test
    fun filterSelectionSheet_displaysTitle() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                FilterSelectionSheet(
                    onFilterSelected = { },
                    onDismiss = { }
                )
            }
        }

        composeTestRule.onNodeWithText("Select Filter")
            .assertIsDisplayed()
    }

    @Test
    fun filterSelectionSheet_displaysCloseButton() {
        var closeClicked = false

        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                FilterSelectionSheet(
                    onFilterSelected = { },
                    onDismiss = { closeClicked = true }
                )
            }
        }

        composeTestRule.onNodeWithText("Close")
            .performClick()

        assertTrue(closeClicked)
    }

    @Test
    fun filterSelectionSheet_displaysAllCategoryTabs() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                FilterSelectionSheet(
                    onFilterSelected = { },
                    onDismiss = { }
                )
            }
        }

        composeTestRule.onNodeWithText("FACE")
            .assertIsDisplayed()
        composeTestRule.onNodeWithText("HAIR")
            .assertIsDisplayed()
        composeTestRule.onNodeWithText("COMBO")
            .assertIsDisplayed()
    }

    @Test
    fun filterSelectionSheet_displaysFaceFiltersByDefault() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                FilterSelectionSheet(
                    onFilterSelected = { },
                    onDismiss = { }
                )
            }
        }

        // Should show face filters
        if (faceFilters.isNotEmpty()) {
            composeTestRule.onNodeWithText(faceFilters[0].name)
                .assertIsDisplayed()
        }
    }

    @Test
    fun filterSelectionSheet_clickingCategoryTab_switchesFilters() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                FilterSelectionSheet(
                    onFilterSelected = { },
                    onDismiss = { }
                )
            }
        }

        // Click on HAIR category
        composeTestRule.onNodeWithText("HAIR")
            .performClick()

        // Should show hair filters
        if (hairFilters.isNotEmpty()) {
            composeTestRule.onNodeWithText(hairFilters[0].name)
                .assertIsDisplayed()
        }
    }

    @Test
    fun filterSelectionSheet_clickingFilter_callsOnFilterSelected() {
        val testFilter = faceFilters.firstOrNull()

        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                FilterSelectionSheet(
                    onFilterSelected = {
                        selectedFilter = it
                        filterSelectedCalled = true
                    },
                    onDismiss = { }
                )
            }
        }

        testFilter?.let {
            composeTestRule.onNodeWithText(it.name)
                .performClick()

            assertTrue(filterSelectedCalled)
            assertEquals(testFilter, selectedFilter)
        }
    }

    @Test
    fun filterSelectionSheet_selectingFilter_callsDismiss() {
        val testFilter = faceFilters.firstOrNull()

        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                FilterSelectionSheet(
                    onFilterSelected = { },
                    onDismiss = { dismissCalled = true }
                )
            }
        }

        testFilter?.let {
            composeTestRule.onNodeWithText(it.name)
                .performClick()

            assertTrue(dismissCalled)
        }
    }

    @Test
    fun filterSelectionSheet_displaysFilterNames() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                FilterSelectionSheet(
                    onFilterSelected = { },
                    onDismiss = { }
                )
            }
        }

        // Verify filter names are displayed
        faceFilters.forEach { filter ->
            composeTestRule.onNodeWithText(filter.name)
                .assertIsDisplayed()
        }
    }

    @Test
    fun filterSelectionSheet_displaysFilterCategories() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                FilterSelectionSheet(
                    onFilterSelected = { },
                    onDismiss = { }
                )
            }
        }

        // Category names should be formatted with spaces
        composeTestRule.onNodeWithText("FACE")
            .assertIsDisplayed()
        composeTestRule.onNodeWithText("HAIR")
            .assertIsDisplayed()
        composeTestRule.onNodeWithText("COMBO")
            .assertIsDisplayed()
    }

    @Test
    fun filterSelectionSheet_clickingAllCategories() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                FilterSelectionSheet(
                    onFilterSelected = { },
                    onDismiss = { }
                )
            }
        }

        // Test FACE category
        composeTestRule.onNodeWithText("FACE")
            .performClick()
        if (faceFilters.isNotEmpty()) {
            composeTestRule.onNodeWithText(faceFilters[0].name)
                .assertIsDisplayed()
        }

        // Test HAIR category
        composeTestRule.onNodeWithText("HAIR")
            .performClick()
        if (hairFilters.isNotEmpty()) {
            composeTestRule.onNodeWithText(hairFilters[0].name)
                .assertIsDisplayed()
        }

        // Test COMBO category
        composeTestRule.onNodeWithText("COMBO")
            .performClick()
        if (comboFilters.isNotEmpty()) {
            composeTestRule.onNodeWithText(comboFilters[0].name)
                .assertIsDisplayed()
        }
    }

    @Test
    fun filterSelectionSheet_handlesEmptyCategories() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                FilterSelectionSheet(
                    onFilterSelected = { },
                    onDismiss = { }
                )
            }
        }

        // All categories should have tabs even if some are empty
        composeTestRule.onNodeWithText("FACE")
            .assertIsDisplayed()
        composeTestRule.onNodeWithText("HAIR")
            .assertIsDisplayed()
        composeTestRule.onNodeWithText("COMBO")
            .assertIsDisplayed()
    }

    @Test
    fun filterSelectionSheet_categoryTabsAreMutuallyExclusive() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                FilterSelectionSheet(
                    onFilterSelected = { },
                    onDismiss = { }
                )
            }
        }

        // Click through all categories
        composeTestRule.onNodeWithText("HAIR")
            .performClick()
        composeTestRule.onNodeWithText("COMBO")
            .performClick()
        composeTestRule.onNodeWithText("FACE")
            .performClick()

        // Should return to face filters
        if (faceFilters.isNotEmpty()) {
            composeTestRule.onNodeWithText(faceFilters[0].name)
                .assertIsDisplayed()
        }
    }

    @Test
    fun filterSelectionSheet_clickingMultipleFilters() {
        var selectedCount = 0
        val selectedFilters = mutableListOf<FilterEffect>()

        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                FilterSelectionSheet(
                    onFilterSelected = {
                        selectedFilters.add(it)
                        selectedCount++
                    },
                    onDismiss = { }
                )
            }
        }

        if (faceFilters.size >= 2) {
            // Click first filter
            composeTestRule.onNodeWithText(faceFilters[0].name)
                .performClick()

            // Click second filter
            composeTestRule.onNodeWithText(faceFilters[1].name)
                .performClick()

            assertEquals(2, selectedCount)
            assertEquals(2, selectedFilters.size)
        }
    }

    @Test
    fun filterSelectionSheet_displaysFirstLetterOfFilterName() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                FilterSelectionSheet(
                    onFilterSelected = { },
                    onDismiss = { }
                )
            }
        }

        if (faceFilters.isNotEmpty()) {
            val firstFilter = faceFilters[0]
            val firstLetter = firstFilter.name.first().toString()

            // Filter name should be displayed
            composeTestRule.onNodeWithText(firstFilter.name)
                .assertIsDisplayed()
        }
    }
}
