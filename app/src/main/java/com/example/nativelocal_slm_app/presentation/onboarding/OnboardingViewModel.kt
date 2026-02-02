package com.example.nativelocal_slm_app.presentation.onboarding

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * ViewModel for managing onboarding state.
 */
class OnboardingViewModel : ViewModel() {

    private val _hasCompletedOnboarding = MutableStateFlow(false)
    val hasCompletedOnboarding: StateFlow<Boolean> = _hasCompletedOnboarding.asStateFlow()

    /**
     * Check if onboarding has been completed.
     * HIGH PRIORITY FIX #5: Moved disk I/O to background thread to prevent blocking main thread.
     */
    fun checkOnboardingStatus(context: Context) {
        viewModelScope.launch(Dispatchers.IO) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val completed = prefs.getBoolean(KEY_ONBOARDING_COMPLETE, false)

            // Switch to Main dispatcher for UI update
            withContext(Dispatchers.Main) {
                _hasCompletedOnboarding.value = completed
            }
        }
    }

    /**
     * Mark onboarding as complete.
     * HIGH PRIORITY FIX #5: Explicitly use Dispatchers.IO for disk I/O.
     */
    fun completeOnboarding(context: Context) {
        viewModelScope.launch(Dispatchers.IO) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putBoolean(KEY_ONBOARDING_COMPLETE, true).apply()

            // Switch to Main dispatcher for UI update
            withContext(Dispatchers.Main) {
                _hasCompletedOnboarding.value = true
            }
        }
    }

    /**
     * Reset onboarding (for testing purposes).
     * HIGH PRIORITY FIX #5: Explicitly use Dispatchers.IO for disk I/O.
     */
    fun resetOnboarding(context: Context) {
        viewModelScope.launch(Dispatchers.IO) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().remove(KEY_ONBOARDING_COMPLETE).apply()

            // Switch to Main dispatcher for UI update
            withContext(Dispatchers.Main) {
                _hasCompletedOnboarding.value = false
            }
        }
    }

    companion object {
        private const val PREFS_NAME = "onboarding_prefs"
        private const val KEY_ONBOARDING_COMPLETE = "onboarding_complete"
    }
}
