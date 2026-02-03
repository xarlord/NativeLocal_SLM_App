package com.example.nativelocal_slm_app.presentation.onboarding

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * ViewModel for managing onboarding state.
 */
class OnboardingViewModel : ViewModel() {

    private val _hasCompletedOnboarding = MutableStateFlow(false)
    val hasCompletedOnboarding: StateFlow<Boolean> = _hasCompletedOnboarding.asStateFlow()

    /**
     * Check if onboarding has been completed.
     */
    fun checkOnboardingStatus(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        _hasCompletedOnboarding.value = prefs.getBoolean(KEY_ONBOARDING_COMPLETE, false)
    }

    /**
     * Mark onboarding as complete.
     */
    fun completeOnboarding(context: Context) {
        viewModelScope.launch {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putBoolean(KEY_ONBOARDING_COMPLETE, true).apply()
            _hasCompletedOnboarding.value = true
        }
    }

    /**
     * Reset onboarding (for testing purposes).
     */
    fun resetOnboarding(context: Context) {
        viewModelScope.launch {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().remove(KEY_ONBOARDING_COMPLETE).apply()
            _hasCompletedOnboarding.value = false
        }
    }

    companion object {
        private const val PREFS_NAME = "onboarding_prefs"
        private const val KEY_ONBOARDING_COMPLETE = "onboarding_complete"
    }
}
