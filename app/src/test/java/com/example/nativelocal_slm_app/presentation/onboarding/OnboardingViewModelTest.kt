package com.example.nativelocal_slm_app.presentation.onboarding

import android.content.Context
import android.content.SharedPreferences
import androidx.arch.core.executor.testing.InstantTaskExecutorRule
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test

/**
 * Unit tests for OnboardingViewModel.
 * Uses UnconfinedTestDispatcher to execute coroutines synchronously for testing.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class OnboardingViewModelTest {

    private lateinit var viewModel: OnboardingViewModel
    private val context: Context = mockk()
    private val sharedPreferences: SharedPreferences = mockk()
    private val editor: SharedPreferences.Editor = mockk()
    private val testDispatcher = UnconfinedTestDispatcher()

    // Rule for LiveData testing (if ViewModel had LiveData)
    @get:Rule
    val instantTaskExecutorRule = InstantTaskExecutorRule()

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        every { context.getSharedPreferences("onboarding_prefs", Context.MODE_PRIVATE) } returns sharedPreferences
        every { sharedPreferences.edit() } returns editor
        every { editor.putBoolean(any(), any()) } returns editor
        every { editor.remove(any()) } returns editor
        every { editor.apply() } returns Unit

        viewModel = OnboardingViewModel()
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `initial state has hasCompletedOnboarding as false`() {
        // Initially, the flow should emit false
        val value = viewModel.hasCompletedOnboarding.value
        assertFalse("Initial state should be false", value)
    }

    @Test
    fun `checkOnboardingStatus reads from SharedPreferences`() {
        every { sharedPreferences.getBoolean("onboarding_complete", false) } returns true

        viewModel.checkOnboardingStatus(context)

        assertTrue("Should be true after checking prefs", viewModel.hasCompletedOnboarding.value)
        verify { context.getSharedPreferences("onboarding_prefs", Context.MODE_PRIVATE) }
        verify { sharedPreferences.getBoolean("onboarding_complete", false) }
    }

    @Test
    fun `checkOnboardingStatus returns false when not completed`() {
        every { sharedPreferences.getBoolean("onboarding_complete", false) } returns false

        viewModel.checkOnboardingStatus(context)

        assertFalse("Should be false when not completed", viewModel.hasCompletedOnboarding.value)
    }

    @Test
    fun `checkOnboardingStatus uses correct default value`() {
        // SharedPreferences returns false when key doesn't exist
        every { sharedPreferences.getBoolean("onboarding_complete", false) } returns false

        viewModel.checkOnboardingStatus(context)

        assertEquals(false, viewModel.hasCompletedOnboarding.value)
    }

    @Test
    fun `completeOnboarding saves to SharedPreferences`() = runTest {
        viewModel.completeOnboarding(context)

        verify(exactly = 1) { context.getSharedPreferences("onboarding_prefs", Context.MODE_PRIVATE) }
        verify { sharedPreferences.edit() }
        verify { editor.putBoolean("onboarding_complete", true) }
        verify { editor.apply() }
        assertTrue("State should be true after completion", viewModel.hasCompletedOnboarding.value)
    }

    @Test
    fun `resetOnboarding removes from SharedPreferences`() = runTest {
        viewModel.resetOnboarding(context)

        verify { context.getSharedPreferences("onboarding_prefs", Context.MODE_PRIVATE) }
        verify { sharedPreferences.edit() }
        verify { editor.remove("onboarding_complete") }
        verify { editor.apply() }
        assertFalse("State should be false after reset", viewModel.hasCompletedOnboarding.value)
    }

    @Test
    fun `completeOnboarding updates state flow`() = runTest {
        every { sharedPreferences.getBoolean("onboarding_complete", false) } returns false

        viewModel.completeOnboarding(context)

        assertTrue("State should update to true", viewModel.hasCompletedOnboarding.value)
    }

    @Test
    fun `resetOnboarding updates state flow`() = runTest {
        // First complete onboarding
        every { sharedPreferences.getBoolean("onboarding_complete", false) } returns true
        viewModel.checkOnboardingStatus(context)
        assertTrue("Should be true after check", viewModel.hasCompletedOnboarding.value)

        // Then reset
        viewModel.resetOnboarding(context)
        assertFalse("Should be false after reset", viewModel.hasCompletedOnboarding.value)
    }

    @Test
    fun `multiple completeOnboarding calls maintain true state`() = runTest {
        viewModel.completeOnboarding(context)
        assertTrue("Should be true after first completion", viewModel.hasCompletedOnboarding.value)

        viewModel.completeOnboarding(context)
        assertTrue("Should still be true after second completion", viewModel.hasCompletedOnboarding.value)

        viewModel.completeOnboarding(context)
        assertTrue("Should still be true after third completion", viewModel.hasCompletedOnboarding.value)
    }

    @Test
    fun `multiple resetOnboarding calls maintain false state`() = runTest {
        viewModel.resetOnboarding(context)
        assertFalse("Should be false after first reset", viewModel.hasCompletedOnboarding.value)

        viewModel.resetOnboarding(context)
        assertFalse("Should still be false after second reset", viewModel.hasCompletedOnboarding.value)

        viewModel.resetOnboarding(context)
        assertFalse("Should still be false after third reset", viewModel.hasCompletedOnboarding.value)
    }

    @Test
    fun `complete then reset then complete works correctly`() = runTest {
        // Complete
        viewModel.completeOnboarding(context)
        assertTrue("Should be true after complete", viewModel.hasCompletedOnboarding.value)

        // Reset
        viewModel.resetOnboarding(context)
        assertFalse("Should be false after reset", viewModel.hasCompletedOnboarding.value)

        // Complete again
        viewModel.completeOnboarding(context)
        assertTrue("Should be true after second complete", viewModel.hasCompletedOnboarding.value)
    }

    @Test
    fun `checkOnboardingStatus after completeOnboarding returns true`() = runTest {
        // Complete onboarding
        viewModel.completeOnboarding(context)
        assertTrue("Should be true after complete", viewModel.hasCompletedOnboarding.value)

        // Check status should read the saved value
        every { sharedPreferences.getBoolean("onboarding_complete", false) } returns true
        viewModel.checkOnboardingStatus(context)

        assertTrue("Should still be true after check", viewModel.hasCompletedOnboarding.value)
    }

    @Test
    fun `checkOnboardingStatus after resetOnboarding returns false`() = runTest {
        // Complete onboarding first
        viewModel.completeOnboarding(context)

        // Reset onboarding
        viewModel.resetOnboarding(context)
        assertFalse("Should be false after reset", viewModel.hasCompletedOnboarding.value)

        // Check status should read the saved value
        every { sharedPreferences.getBoolean("onboarding_complete", false) } returns false
        viewModel.checkOnboardingStatus(context)

        assertFalse("Should still be false after check", viewModel.hasCompletedOnboarding.value)
    }

    @Test
    fun `StateFlow emits correct values over lifecycle`() = runTest {
        // Collect values
        val values = mutableListOf<Boolean>()
        // Note: In a real test you'd use Turbine or similar to test Flow emissions
        // For StateFlow, we can just check .value at different points

        // Initial value
        values.add(viewModel.hasCompletedOnboarding.value)

        // Complete onboarding
        viewModel.completeOnboarding(context)
        values.add(viewModel.hasCompletedOnboarding.value)

        // Reset onboarding
        viewModel.resetOnboarding(context)
        values.add(viewModel.hasCompletedOnboarding.value)

        // Complete again
        viewModel.completeOnboarding(context)
        values.add(viewModel.hasCompletedOnboarding.value)

        assertEquals(listOf(false, true, false, true), values)
    }
}
