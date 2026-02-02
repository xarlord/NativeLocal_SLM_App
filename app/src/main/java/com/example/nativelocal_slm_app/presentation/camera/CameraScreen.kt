package com.example.nativelocal_slm_app.presentation.camera

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Camera
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OptIn
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.nativelocal_slm_app.domain.model.FilterEffect
import com.example.nativelocal_slm_app.presentation.filters.FilterCarousel
import com.example.nativelocal_slm_app.presentation.filters.FilterSelectionSheet
import com.example.nativelocal_slm_app.presentation.filters.StyleSelectionSheet
import org.koin.androidx.compose.koinViewModel

/**
 * Main camera screen with real-time hair analysis and filter application.
 */
@Composable
fun CameraScreen(
    viewModel: CameraViewModel = koinViewModel(),
    onFilterClick: () -> Unit = {},
    onPhotoCaptured: (CapturedPhoto) -> Unit = {}
) {
    val cameraState by viewModel.cameraState.collectAsState()
    val processedBitmap by viewModel.processedBitmap.collectAsState()
    val selectedFilter by viewModel.selectedFilter.collectAsState()
    val capturedPhoto by viewModel.capturedPhoto.collectAsState()

    var showFilterSheet by remember { mutableStateOf(false) }
    var showStyleSheet by remember { mutableStateOf(false) }
    var showColorPicker by remember { mutableStateOf(false) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        // Camera preview
        CameraPreview(
            viewModel = viewModel,
            modifier = Modifier.fillMaxSize()
        )

        // Filter overlay (if selected)
        val bitmap = processedBitmap
        if (selectedFilter != null && bitmap != null) {
            Image(
                bitmap = bitmap.asImageBitmap(),
                contentDescription = "Filtered camera frame",
                modifier = Modifier
                    .fillMaxSize()
                    .zIndex(1f)
            )
        }

        // Top bar
        TopAppBar(
            selectedFilter = selectedFilter,
            onCloseFilter = { viewModel.selectFilter(null) },
            onFilterClick = { showFilterSheet = true },
            modifier = Modifier
                .align(Alignment.TopCenter)
                .fillMaxWidth()
                .padding(16.dp)
                .zIndex(2f)
        )

        // Filter carousel (when no filter selected)
        if (selectedFilter == null) {
            Box(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(top = 80.dp)
                    .zIndex(2f)
            ) {
                FilterCarousel(
                    selectedFilter = null,
                    onFilterSelected = { filter ->
                        viewModel.selectFilter(filter)
                    }
                )
            }
        }

        // Bottom controls
        CameraControls(
            onCaptureClick = {
                viewModel.capturePhoto()
            },
            onStyleClick = { showStyleSheet = true },
            onColorClick = { showColorPicker = true },
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .padding(24.dp)
                .zIndex(2f)
            )
    }

    // Filter selection sheet
    if (showFilterSheet) {
        FilterSelectionSheet(
            onFilterSelected = { filter ->
                viewModel.selectFilter(filter)
                showFilterSheet = false
            },
            onDismiss = { showFilterSheet = false }
        )
    }

    // Handle captured photo
    LaunchedEffect(capturedPhoto) {
        capturedPhoto?.let { photo ->
            onPhotoCaptured(photo)
            viewModel.clearCapturedPhoto()
        }
    }
}

@Composable
private fun TopAppBar(
    selectedFilter: FilterEffect?,
    onCloseFilter: () -> Unit,
    onFilterClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (selectedFilter != null) {
            // Filter indicator with close button
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    text = selectedFilter.name,
                    style = MaterialTheme.typography.titleMedium,
                    color = Color.White
                )
                IconButton(onClick = onCloseFilter) {
                    Icon(
                        imageVector = Icons.Filled.Close,
                        contentDescription = "Close filter",
                        tint = Color.White
                    )
                }
            }
        } else {
            // Select filter button
            Button(
                onClick = onFilterClick,
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color.White.copy(alpha = 0.2f)
                )
            ) {
                Text("Select Filter", color = Color.White)
            }
        }
    }
}

@Composable
private fun CameraControls(
    onCaptureClick: () -> Unit,
    onStyleClick: () -> Unit,
    onColorClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Style button
        CameraControlButton(
            icon = { Text("✂️", style = MaterialTheme.typography.titleLarge) },
            onClick = onStyleClick
        )

        // Capture button (larger, centered)
        CaptureButton(onClick = onCaptureClick)

        // Color button
        CameraControlButton(
            icon = { Text("🎨", style = MaterialTheme.typography.titleLarge) },
            onClick = onColorClick
        )
    }
}

@Composable
private fun CaptureButton(onClick: () -> Unit) {
    Button(
        onClick = onClick,
        modifier = Modifier
            .size(80.dp)
            .clip(CircleShape),
        colors = ButtonDefaults.buttonColors(
            containerColor = Color.White
        ),
        contentPadding = PaddingValues(0.dp),
        shape = CircleShape
    ) {
        Icon(
            imageVector = Icons.Filled.Camera,
            contentDescription = "Capture photo",
            tint = Color.Black,
            modifier = Modifier.size(36.dp)
        )
    }
}

@Composable
private fun CameraControlButton(
    icon: @Composable () -> Unit,
    onClick: () -> Unit
) {
    Button(
        onClick = onClick,
        modifier = Modifier
            .size(56.dp)
            .clip(CircleShape),
        colors = ButtonDefaults.buttonColors(
            containerColor = Color.White.copy(alpha = 0.2f)
        ),
        contentPadding = PaddingValues(0.dp),
        shape = CircleShape
    ) {
        icon()
    }
}
