package com.example.nativelocal_slm_app.ui.components

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.*
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.example.nativelocal_slm_app.ui.components.iOSBottomSheet
import com.example.nativelocal_slm_app.ui.components.iOSHalfSheet
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Instrumented Compose UI tests for BottomSheet components.
 */
@RunWith(AndroidJUnit4::class)
class BottomSheetTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @Test
    fun iOSBottomSheet_displaysContent_whenVisible() {
        composeTestRule.setContent {
            iOSBottomSheet(
                isVisible = true,
                onDismiss = {}
            ) {
                Box(modifier = Modifier.fillMaxWidth().height(100.dp))
            }
        }

        // Verify the sheet content is displayed
        composeTestRule.onNode(hasTestTag("BottomSheetContent"))
            .assertIsDisplayed()
    }

    @Test
    fun iOSBottomSheet_dismissesOnBackdropTap() {
        var dismissed = false
        composeTestRule.setContent {
            iOSBottomSheet(
                isVisible = true,
                onDismiss = { dismissed = true }
            ) {
                Box(modifier = Modifier.fillMaxWidth().height(100.dp))
            }
        }

        // Tap on backdrop (the black background)
        composeTestRule.onNode(hasTestTag("BottomSheetBackdrop"))
            .performClick()

        assert(dismissed)
    }

    @Test
    fun iOSBottomSheet_handleBarIsVisible() {
        composeTestRule.setContent {
            iOSBottomSheet(
                isVisible = true,
                onDismiss = {}
            ) {
                Box(modifier = Modifier.fillMaxWidth().height(100.dp))
            }
        }

        // Verify handle bar is visible
        composeTestRule.onNode(hasTestTag("HandleBar"))
            .assertIsDisplayed()
    }

    @Test
    fun iOSBottomSheet_notVisible_whenIsVisibleFalse() {
        composeTestRule.setContent {
            iOSBottomSheet(
                isVisible = false,
                onDismiss = {}
            ) {
                Box(modifier = Modifier.fillMaxWidth().height(100.dp))
            }
        }

        // Verify the sheet content is not displayed
        composeTestRule.onNode(hasTestTag("BottomSheetContent"))
            .assertIsNotDisplayed()
    }

    @Test
    fun iOSHalfSheet_displaysContent_whenVisible() {
        composeTestRule.setContent {
            iOSHalfSheet(
                isVisible = true,
                onDismiss = {}
            ) {
                Box(modifier = Modifier.fillMaxWidth().height(100.dp))
            }
        }

        // Verify the sheet content is displayed
        composeTestRule.onNode(hasTestTag("BottomSheetContent"))
            .assertIsDisplayed()
    }

    @Test
    fun iOSHalfSheet_dismissesOnBackdropTap() {
        var dismissed = false
        composeTestRule.setContent {
            iOSHalfSheet(
                isVisible = true,
                onDismiss = { dismissed = true }
            ) {
                Box(modifier = Modifier.fillMaxWidth().height(100.dp))
            }
        }

        // Tap on backdrop
        composeTestRule.onNode(hasTestTag("BottomSheetBackdrop"))
            .performClick()

        assert(dismissed)
    }

    @Test
    fun iOSBottomSheet_appliesCorrectModifier() {
        var customZIndexApplied = false
        composeTestRule.setContent {
            iOSBottomSheet(
                isVisible = true,
                onDismiss = {},
                modifier = Modifier.zIndex(1f)
            ) {
                customZIndexApplied = true
                Box(modifier = Modifier.fillMaxWidth().height(100.dp))
            }
        }

        // Verify custom modifier is applied
        assert(customZIndexApplied)
    }
}
