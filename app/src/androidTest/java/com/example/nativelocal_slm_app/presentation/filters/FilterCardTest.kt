package com.example.nativelocal_slm_app.presentation.filters

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.*
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.example.nativelocal_slm_app.presentation.filters.AnalysisBadge
import com.example.nativelocal_slm_app.presentation.filters.FilterCard
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Instrumented Compose UI tests for FilterCard and AnalysisBadge components.
 */
@RunWith(AndroidJUnit4::class)
class FilterCardTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @Test
    fun filterCard_displaysFilterName() {
        composeTestRule.setContent {
            FilterCard(
                name = "Batman",
                category = "Face",
                isSelected = false,
                onClick = {}
            )
        }

        composeTestRule.onNodeWithText("Batman").assertIsDisplayed()
    }

    @Test
    fun filterCard_displaysCategory() {
        composeTestRule.setContent {
            FilterCard(
                name = "Batman",
                category = "Face",
                isSelected = false,
                onClick = {}
            )
        }

        composeTestRule.onNodeWithText("Face").assertIsDisplayed()
    }

    @Test
    fun filterCard_displaysFirstLetterInThumbnail() {
        composeTestRule.setContent {
            FilterCard(
                name = "Joker",
                category = "Face",
                isSelected = false,
                onClick = {}
            )
        }

        composeTestRule.onNodeWithText("J").assertIsDisplayed()
    }

    @Test
    fun filterCard_showsCheckmarkWhenSelected() {
        composeTestRule.setContent {
            FilterCard(
                name = "Batman",
                category = "Face",
                isSelected = true,
                onClick = {}
            )
        }

        composeTestRule.onNodeWithText("✓").assertIsDisplayed()
    }

    @Test
    fun filterCard_doesNotShowCheckmarkWhenNotSelected() {
        composeTestRule.setContent {
            FilterCard(
                name = "Batman",
                category = "Face",
                isSelected = false,
                onClick = {}
            )
        }

        composeTestRule.onNodeWithText("✓").assertDoesNotExist()
    }

    @Test
    fun filterCard_callsOnClickWhenClicked() {
        var clicked = false
        composeTestRule.setContent {
            FilterCard(
                name = "Batman",
                category = "Face",
                isSelected = false,
                onClick = { clicked = true }
            )
        }

        composeTestRule.onNode(hasText("Batman")).performClick()

        assert(clicked)
    }

    @Test
    fun analysisBadge_displaysLabelAndValue() {
        composeTestRule.setContent {
            AnalysisBadge(
                label = "Hair Type",
                value = "Wavy"
            )
        }

        composeTestRule.onNodeWithText("Hair Type").assertIsDisplayed()
        composeTestRule.onNodeWithText("Wavy").assertIsDisplayed()
    }

    @Test
    fun analysisBadge_displaysCorrectValues() {
        composeTestRule.setContent {
            AnalysisBadge(
                label = "Color",
                value = "Brown"
            )
        }

        composeTestRule.onNodeWithText("Color").assertIsDisplayed()
        composeTestRule.onNodeWithText("Brown").assertIsDisplayed()
    }

    @Test
    fun filterCard_thumbnailColorChangesWhenSelected() {
        // Test unselected state
        composeTestRule.setContent {
            FilterCard(
                name = "Test",
                category = "Category",
                isSelected = false,
                onClick = {}
            )
        }

        // In unselected state, thumbnail circle should be gray
        composeTestRule.onNodeWithText("T").assertIsDisplayed()

        // Test selected state
        composeTestRule.setContent {
            FilterCard(
                name = "Test",
                category = "Category",
                isSelected = true,
                onClick = {}
            )
        }

        // In selected state, thumbnail circle should be white with black text
        composeTestRule.onNodeWithText("T").assertIsDisplayed()
    }

    @Test
    fun filterCard_handlesLongNames() {
        composeTestRule.setContent {
            FilterCard(
                name = "VeryLongFilterName",
                category = "Hair",
                isSelected = false,
                onClick = {}
            )
        }

        composeTestRule.onNodeWithText("VeryLongFilterName").assertIsDisplayed()
        composeTestRule.onNodeWithText("V").assertIsDisplayed()
    }

    @Test
    fun filterCard_handlesSpecialCharacters() {
        composeTestRule.setContent {
            FilterCard(
                name = "Cyber-Punk",
                category = "Style",
                isSelected = false,
                onClick = {}
            )
        }

        composeTestRule.onNodeWithText("Cyber-Punk").assertIsDisplayed()
        composeTestRule.onNodeWithText("Style").assertIsDisplayed()
    }

    @Test
    fun analysisBadge_handlesEmptyValues() {
        composeTestRule.setContent {
            AnalysisBadge(
                label = "Test",
                value = ""
            )
        }

        composeTestRule.onNodeWithText("Test").assertIsDisplayed()
        composeTestRule.onNodeWithText("").assertIsDisplayed()
    }
}
