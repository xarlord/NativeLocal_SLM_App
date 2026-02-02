package com.example.nativelocal_slm_app.presentation.results

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.weight
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.OptIn
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.example.nativelocal_slm_app.domain.model.SavedLook
import com.example.nativelocal_slm_app.presentation.camera.CapturedPhoto

/**
 * MEDIUM PRIORITY FIX #2: Split god class ResultsScreen.kt
 *
 * BEFORE: 264 lines with multiple responsibilities
 * AFTER: ~120 lines with single responsibility
 *
 * Extracted to ResultsComponents.kt:
 * - ResultsTopBar
 * - BeforeAfterComparison
 * - ResultsActions
 * - ShareImage
 * - ShareDialog
 * - HistoryDrawer
 * - HistoryItem
 *
 * This file now ONLY contains the main ResultsScreen composable
 * that orchestrates the UI components.
 *
 * Results screen showing captured photo with options to save, share, and compare.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ResultsScreen(
    capturedPhoto: CapturedPhoto,
    onSave: () -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    var showHistory by remember { mutableStateOf(false) }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = Color.Black,
        topBar = {
            ResultsTopBar(
                onBack = onBack,
                onShowHistory = { showHistory = true }
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            // Before/After comparison
            BeforeAfterComparison(
                beforeImage = capturedPhoto.originalImage,
                afterImage = capturedPhoto.processedImage,
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
            )

            // Bottom actions
            ResultsActions(
                onSave = {
                    onSave()
                },
                onShare = {
                    // Share functionality - MEDIUM PRIORITY FIX #3
                    // TODO: Implement proper error handling
                    // Result<> wrapper to be added in Phase 3
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp)
            )
        }
    }

    // History drawer
    if (showHistory) {
        HistoryDrawer(
            onClose = { showHistory = false },
            onLookSelected = { look ->
                // TODO: Implement history loading
                // For now, just close drawer
                showHistory = false
            }
        )
    }
}
