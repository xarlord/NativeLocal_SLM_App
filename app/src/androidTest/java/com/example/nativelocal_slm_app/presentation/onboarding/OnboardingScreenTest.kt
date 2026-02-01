package com.example.nativelocal_slm_app.presentation.onboarding

import androidx.compose.ui.test.*
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.example.nativelocal_slm_app.presentation.onboarding.OnboardingPage
import com.example.nativelocal_slm_app.presentation.onboarding.OnboardingScreen
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Instrumented Compose UI tests for OnboardingScreen.
 */
@RunWith(AndroidJUnit4::class)
class OnboardingScreenTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @Test
    fun onboardingScreen_displaysFirstPage() {
        var onCompleteCalled = false
        composeTestRule.setContent {
            OnboardingScreen(
                onComplete = { onCompleteCalled = true }
            )
        }

        // Verify first page content is displayed
        composeTestRule.onNodeWithText("Welcome to Hair Analysis").assertIsDisplayed()
        composeTestRule.onNodeWithText("Discover your hair type, color, and style with our advanced AI-powered analysis.").assertIsDisplayed()
        composeTestRule.onNodeWithText("💇").assertIsDisplayed()
    }

    @Test
    fun onboardingScreen_displaysAllPages() {
        lateinit var pages: List<OnboardingPage>
        composeTestRule.setContent {
            pages = OnboardingPage.values().toList()
            OnboardingScreen(onComplete = {})
        }

        // Verify we have 4 pages
        assert(pages.size == 4)
        assert(pages[0] == OnboardingPage.WELCOME)
        assert(pages[1] == OnboardingPage.CAMERA)
        assert(pages[2] == OnboardingPage.FILTERS)
        assert(pages[3] == OnboardingPage.SAVE_SHARE)
    }

    @Test
    fun onboardingScreen_pageIndicatorsVisible() {
        composeTestRule.setContent {
            OnboardingScreen(onComplete = {})
        }

        // Verify page indicators are displayed (4 indicators for 4 pages)
        composeTestRule.onAllNodes(hasTestTag("PageIndicator"))
            .assertCountEquals(4)
    }

    @Test
    fun onboardingScreen_nextButtonNavigatesToNextPage() {
        composeTestRule.setContent {
            OnboardingScreen(onComplete = {})
        }

        // Click next button
        composeTestRule.onNodeWithText("Next").performClick()

        // Verify second page content is displayed
        composeTestRule.onNodeWithText("Real-Time Analysis").assertIsDisplayed()
    }

    @Test
    fun onboardingScreen_getStartedButtonAppearsOnLastPage() {
        composeTestRule.setContent {
            OnboardingScreen(onComplete = {})
        }

        // Navigate to last page by clicking Next 3 times
        composeTestRule.onNodeWithText("Next").performClick()
        composeTestRule.onNodeWithText("Next").performClick()
        composeTestRule.onNodeWithText("Next").performClick()

        // Verify "Get Started" button is displayed
        composeTestRule.onNodeWithText("Get Started").assertIsDisplayed()
    }

    @Test
    fun onboardingScreen_skipButtonVisibleOnFirstPage() {
        composeTestRule.setContent {
            OnboardingScreen(onComplete = {})
        }

        // Verify Skip button is displayed on first page
        composeTestRule.onNodeWithText("Skip").assertIsDisplayed()
    }

    @Test
    fun onboardingScreen_skipButtonNotVisibleOnLastPage() {
        composeTestRule.setContent {
            OnboardingScreen(onComplete = {})
        }

        // Navigate to last page
        composeTestRule.onNodeWithText("Next").performClick()
        composeTestRule.onNodeWithText("Next").performClick()
        composeTestRule.onNodeWithText("Next").performClick()

        // Verify Skip button is not displayed
        composeTestRule.onNodeWithText("Skip").assertIsNotDisplayed()
    }

    @Test
    fun onboardingScreen_onCompleteCalledWhenGetStartedClicked() {
        var onCompleteCalled = false
        composeTestRule.setContent {
            OnboardingScreen(
                onComplete = { onCompleteCalled = true }
            )
        }

        // Navigate to last page
        composeTestRule.onNodeWithText("Next").performClick()
        composeTestRule.onNodeWithText("Next").performClick()
        composeTestRule.onNodeWithText("Next").performClick()

        // Click Get Started
        composeTestRule.onNodeWithText("Get Started").performClick()

        // Verify onComplete was called
        assert(onCompleteCalled)
    }

    @Test
    fun onboardingScreen_onCompleteCalledWhenSkipClicked() {
        var onCompleteCalled = false
        composeTestRule.setContent {
            OnboardingScreen(
                onComplete = { onCompleteCalled = true }
            )
        }

        // Click Skip
        composeTestRule.onNodeWithText("Skip").performClick()

        // Verify onComplete was called
        assert(onCompleteCalled)
    }

    @Test
    fun onboardingScreen_displaysCorrectEmojiForEachPage() {
        composeTestRule.setContent {
            OnboardingScreen(onComplete = {})
        }

        // First page emoji
        composeTestRule.onNodeWithText("💇").assertIsDisplayed()

        // Navigate to second page
        composeTestRule.onNodeWithText("Next").performClick()
        composeTestRule.onNodeWithText("📸").assertIsDisplayed()

        // Navigate to third page
        composeTestRule.onNodeWithText("Next").performClick()
        composeTestRule.onNodeWithText("🎨").assertIsDisplayed()

        // Navigate to fourth page
        composeTestRule.onNodeWithText("Next").performClick()
        composeTestRule.onNodeWithText("📱").assertIsDisplayed()
    }
}
