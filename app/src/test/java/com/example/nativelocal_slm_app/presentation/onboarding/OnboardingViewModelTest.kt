package com.example.nativelocal_slm_app.presentation.onboarding

import android.content.Context
import android.content.SharedPreferences
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
import org.junit.Before
import org.junit.Test

/**
 * Unit tests for OnboardingViewModel.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class OnboardingViewModelTest {

    private lateinit var viewModel: OnboardingViewModel
    private val context: Context = mockk()
    private val sharedPreferences: SharedPreferences = mockk()
    private val editor: SharedPreferences.Editor = mockk()
    private val testDispatcher = UnconfinedTestDispatcher()

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
        assert(value == false)
    }

    @Test
    fun `checkOnboardingStatus reads from SharedPreferences`() {
        every { sharedPreferences.getBoolean("onboarding_complete", false) } returns true

        viewModel.checkOnboardingStatus(context)

        assert(viewModel.hasCompletedOnboarding.value == true)
        verify { context.getSharedPreferences("onboarding_prefs", Context.MODE_PRIVATE) }
        verify { sharedPreferences.getBoolean("onboarding_complete", false) }
    }

    @Test
    fun `checkOnboardingStatus returns false when not completed`() {
        every { sharedPreferences.getBoolean("onboarding_complete", false) } returns false

        viewModel.checkOnboardingStatus(context)

        assert(viewModel.hasCompletedOnboarding.value == false)
    }

    @Test
    fun `completeOnboarding saves to SharedPreferences`() = runTest {
        viewModel.completeOnboarding(context)

        verify { context.getSharedPreferences("onboarding_prefs", Context.MODE_PRIVATE) }
        verify { sharedPreferences.edit() }
        verify { editor.putBoolean("onboarding_complete", true) }
        verify { editor.apply() }
        assert(viewModel.hasCompletedOnboarding.value == true)
    }

    @Test
    fun `resetOnboarding removes from SharedPreferences`() = runTest {
        viewModel.resetOnboarding(context)

        verify { context.getSharedPreferences("onboarding_prefs", Context.MODE_PRIVATE) }
        verify { sharedPreferences.edit() }
        verify { editor.remove("onboarding_complete") }
        verify { editor.apply() }
        assert(viewModel.hasCompletedOnboarding.value == false)
    }

    @Test
    fun `completeOnboarding updates state flow`() = runTest {
        every { sharedPreferences.getBoolean("onboarding_complete", false) } returns false

        viewModel.completeOnboarding(context)

        assert(viewModel.hasCompletedOnboarding.value == true)
    }

    @Test
    fun `resetOnboarding updates state flow`() = runTest {
        // First complete onboarding
        every { sharedPreferences.getBoolean("onboarding_complete", false) } returns true
        viewModel.checkOnboardingStatus(context)
        assert(viewModel.hasCompletedOnboarding.value == true)

        // Then reset
        viewModel.resetOnboarding(context)
        assert(viewModel.hasCompletedOnboarding.value == false)
    }

    @Test
    fun `multiple completeOnboarding calls maintain true state`() = runTest {
        viewModel.completeOnboarding(context)
        assert(viewModel.hasCompletedOnboarding.value == true)

        viewModel.completeOnboarding(context)
        assert(viewModel.hasCompletedOnboarding.value == true)
    }
}
