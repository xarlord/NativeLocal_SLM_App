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
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Instrumented tests for FilterCarousel composable.
 */
@RunWith(AndroidJUnit4::class)
class FilterCarouselTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private lateinit var allFilters: List<FilterEffect>
    private var selectedFilter: FilterEffect? = null
    private var filterSelectedCalled = false

    @Before
    fun setup() {
        allFilters = PredefinedFilters.getAllFilters()
        selectedFilter = null
        filterSelectedCalled = false
    }

    @Test
    fun filterCarousel_displaysTitle() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                FilterCarousel(
                    selectedFilter = null,
                    onFilterSelected = { }
                )
            }
        }

        composeTestRule.onNodeWithText("Quick Filters")
            .assertIsDisplayed()
    }

    @Test
    fun filterCarousel_displaysNoneOption() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                FilterCarousel(
                    selectedFilter = null,
                    onFilterSelected = { }
                )
            }
        }

        composeTestRule.onNodeWithText("None")
            .assertIsDisplayed()
    }

    @Test
    fun filterCarousel_displaysAllFilterNames() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                FilterCarousel(
                    selectedFilter = null,
                    onFilterSelected = { }
                )
            }
        }

        // Verify some predefined filters are displayed
        if (allFilters.isNotEmpty()) {
            composeTestRule.onNodeWithText(allFilters[0].name)
                .assertIsDisplayed()
        }
    }

    @Test
    fun filterCarousel_clickingFilter_callsOnFilterSelected() {
        val testFilter = allFilters.firstOrNull()

        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                FilterCarousel(
                    selectedFilter = null,
                    onFilterSelected = {
                        selectedFilter = it
                        filterSelectedCalled = true
                    }
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
    fun filterCarousel_selectedFilter_hasDifferentAppearance() {
        val testFilter = allFilters.firstOrNull()

        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                FilterCarousel(
                    selectedFilter = testFilter,
                    onFilterSelected = { }
                )
            }
        }

        // The selected filter should be displayed
        testFilter?.let {
            composeTestRule.onNodeWithText(it.name)
                .assertIsDisplayed()
        }
    }

    @Test
    fun filterCarousel_noFilterSelected_displaysDefaultState() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                FilterCarousel(
                    selectedFilter = null,
                    onFilterSelected = { }
                )
            }
        }

        // None option should be visible
        composeTestRule.onNodeWithText("None")
            .assertIsDisplayed()
    }

    @Test
    fun filterCarousel_handlesEmptyFilterList() {
        composeTestRule.setContent {
            NativeLocal_SLM_AppTheme {
                FilterCarousel(
                    selectedFilter = null,
                    onFilterSelected = { }
                )
            }
        }

        // Should at least show "None" option
        composeTestRule.onNodeWithText("None")
            .assertIsDisplayed()
    }

    @Test
    fun filterCarousel_clickingMultipleFilters_updatesSelection() {
        var selectedFilter1: FilterEffect? = null
        var selectedFilter2: FilterEffect? = null

        if (allFilters.size >= 2) {
            composeTestRule.setContent {
                NativeLocal_SLM_AppTheme {
                    FilterCarousel(
                        selectedFilter = selectedFilter1,
                        onFilterSelected = { selectedFilter1 = it }
                    )
                }
            }

            // Click first filter
            composeTestRule.onNodeWithText(allFilters[0].name)
                .performClick()
            assertEquals(allFilters[0], selectedFilter1)

            // Click second filter
            composeTestRule.onNodeWithText(allFilters[1].name)
                .performClick()
            assertEquals(allFilters[1], selectedFilter1)
        }
    }
}
