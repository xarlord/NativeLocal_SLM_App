package com.example.nativelocal_slm_app.presentation.results

import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.weight
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.example.nativelocal_slm_app.domain.model.SavedLook
import com.example.nativelocal_slm_app.presentation.camera.CapturedPhoto
import java.io.File

/**
 * Top bar for the results screen.
 */
@Composable
fun ResultsTopBar(
    onBack: () -> Unit,
    onShowHistory: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        IconButton(onClick = onBack) {
            Icon(
                image = Icons.Default.ArrowBack,
                contentDescription = "Back",
                tint = Color.White
            )
        }

        Text(
            text = "Results",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )

        IconButton(onClick = onShowHistory) {
            Icon(
                image = Icons.Filled.History,
                contentDescription = "History",
                tint = Color.White
            )
        }
    }
}

/**
 * Before/After comparison slider.
 * Allows user to compare original and filtered photos.
 */
@Composable
fun BeforeAfterComparison(
    beforeImage: android.graphics.Bitmap,
    afterImage: android.graphics.Bitmap,
    modifier: Modifier = Modifier
) {
    var sliderPosition by remember { mutableStateOf(0.5f) }

    Column(modifier = modifier) {
        Text(
            text = "Before / After",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = Color.White,
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
        )

        // Comparison container
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(16f / 9f)
                .background(Color.Black)
                .clip(RoundedCornerShape(16.dp))
        ) {
            // Before image (left side, partially visible)
            androidx.compose.ui.graphics.Color.apply(
                Canvas(modifier = Modifier.fillMaxSize()) {
                    drawInto {
                        val scaleFactor = size.width / beforeImage.width.toFloat()
                        val scaledWidth = beforeImage.width * scaleFactor
                        val scaledHeight = beforeImage.height * scaleFactor
                        val scaledBefore = android.graphics.Bitmap.createScaledBitmap(
                            beforeImage,
                            scaledWidth.toInt(),
                            scaledHeight.toInt(),
                            true
                        )
                        drawImage(
                            scaledBefore,
                            null,
                            Paint()
                        )
                    }
                }
            )

            // After image (right side, partially visible based on slider)
            androidx.compose.ui.graphics.Color.apply(
                Canvas(modifier = Modifier.fillMaxSize()) {
                    drawInto {
                        val scaleFactor = size.width / afterImage.width.toFloat()
                        val scaledWidth = afterImage.width * scaleFactor
                        val scaledHeight = afterImage.height * scaleFactor
                        val scaledAfter = android.graphics.Bitmap.createScaledBitmap(
                            afterImage,
                            scaledWidth.toInt(),
                            scaledHeight.toInt(),
                            true
                        )
                        drawImage(
                            scaledAfter,
                            null,
                            Paint()
                        )
                    }
                }
            )

            // Slider overlay
            Column(
                modifier = Modifier
                    .align(Alignment.Center)
                    .fillMaxHeight(),
                verticalArrangement = Arrangement.Center
            ) {
                Slider(
                    value = sliderPosition,
                    onValueChange = { sliderPosition = it },
                    valueRange = 0f..1f,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 32.dp)
                        .background(
                            Color.Black.copy(alpha = 0.3f),
                            RoundedCornerShape(8.dp)
                        ),
                    colors = SliderDefaults.colors(
                        thumbColor = Color.White,
                        activeTrackColor = Color.White.copy(alpha = 0.5f),
                        inactiveTrackColor = Color.White.copy(alpha = 0.2f)
                    )
                )

                Text(
                    text = "Slide to compare",
                    style = MaterialTheme.typography.labelSmall,
                    color = Color.White
                )
            }
        }
    }
}

/**
 * Action buttons for saving, sharing, and viewing history.
 */
@Composable
fun ResultsActions(
    onSave: () -> Unit,
    onShare: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Save button
        Button(
            onClick = onSave,
            modifier = Modifier
                .weight(1f)
                .height(56.dp),
            shape = RoundedCornerShape(28.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = Color.White,
                contentColor = Color.Black
            )
        ) {
            Text("Save", style = MaterialTheme.typography.titleMedium)
        }

        // Share button
        Button(
            onClick = onShare,
            modifier = Modifier
                .weight(1f)
                .height(56.dp),
            shape = RoundedCornerShape(28.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = Color.Gray,
                contentColor = Color.White
            )
        ) {
            Icon(
                image = Icons.Filled.Share,
                contentDescription = "Share",
                modifier = Modifier.size(24.dp)
            )
        }
    }
}

/**
 * Share functionality for images.
 */
@Composable
fun ShareImage(
    context: Context,
    image: android.graphics.Bitmap
) {
    val scope = rememberCoroutineScope()
    var showShareDialog by remember { mutableStateOf(false) }

    // Show share dialog on button click
    LaunchedEffect(Unit) {
        showShareDialog = true
    }

    if (showShareDialog) {
        ShareDialog(
            onDismiss = { showShareDialog = false },
            onShareTo = { platform ->
                shareImageTo(context, image, platform)
            }
        )
    }
}

/**
 * Share dialog with platform options.
 */
@Composable
fun ShareDialog(
    onDismiss: () -> Unit,
    onShareTo: (String) -> Unit
) {
    AlertDialog(
        onDismissRequest = { onDismiss() },
        title = { Text("Share Image") },
        text = { Text("Choose a platform to share the image") },
        confirmButton = {
            TextButton(onClick = { onDismiss() }) {
                Text("Cancel")
            }
        }
    )
}

/**
 * Share image to a specific platform.
 */
private fun shareImageTo(context: Context, image: android.graphics.Bitmap, platform: String) {
    // TODO: Implement actual sharing logic
    // For now, just show a placeholder
}

/**
 * History drawer showing saved looks.
 */
@Composable
fun HistoryDrawer(
    onClose: () -> Unit,
    onLookSelected: (SavedLook) -> Unit
) {
    val scope = rememberCoroutineScope()
    var savedLooks by remember { mutableStateOf<List<SavedLook>>(emptyList()) }

    // Load saved looks when drawer opens
    LaunchedEffect(Unit) {
        // TODO: Load saved looks from repository
        // savedLooks = saveLookUseCase.loadSavedLooks()
    }

    ModalDrawerSheet(
        onDismissRequest = { onClose() },
        sheetState = ModalBottomSheetValueState(expanded = true)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .height(400.dp)
                .background(Color.Black)
                .padding(16.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "History",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )

                IconButton(onClick = onClose) {
                    Icon(
                        image = Icons.Default.Close,
                        contentDescription = "Close",
                        tint = Color.White
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            if (savedLooks.isEmpty()) {
                Text(
                    text = "No saved looks yet",
                    style = MaterialTheme.typography.bodyMedium,
                    color = Color.Gray,
                    modifier = Modifier.align(Alignment.Center)
                )
            } else {
                LazyColumn(
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(savedLooks) { look ->
                        HistoryItem(
                            savedLook = look,
                            onClick = {
                                onLookSelected(look)
                                onClose()
                            }
                        )
                    }
                }
            }
        }
    }
}

/**
 * Individual history item displaying a saved look.
 */
@Composable
private fun HistoryItem(
    savedLook: SavedLook,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(
            containerColor = Color.White.copy(alpha = 0.1f)
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Thumbnail
            AsyncImage(
                model = savedLook.resultImage.toString(),
                modifier = Modifier
                    .size(60.dp)
                    .clip(CircleShape),
                contentDescription = "Saved look"
            )

            Spacer(modifier = Modifier.width(16.dp))

            // Info
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = savedLook.getFormattedTimestamp(),
                    style = MaterialTheme.typography.labelSmall,
                    color = Color.Gray
                )

                Spacer(modifier = Modifier.height(4.dp))

                Text(
                    text = savedLook.getAppliedFilterNames(),
                    style = MaterialTheme.typography.bodyMedium,
                    color = Color.White,
                    maxLines = 2
                )
            }
        }
    }
}
