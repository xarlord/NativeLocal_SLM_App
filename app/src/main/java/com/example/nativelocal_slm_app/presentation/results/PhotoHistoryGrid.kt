package com.example.nativelocal_slm_app.presentation.results

import android.net.Uri
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.example.nativelocal_slm_app.data.model.SavedLook

/**
 * Grid view of saved looks for history and management.
 */
@Composable
fun PhotoHistoryGrid(
    savedLooks: List<SavedLook>,
    onLookClick: (SavedLook) -> Unit,
    onDeleteClick: (SavedLook) -> Unit,
    modifier: Modifier = Modifier
) {
    if (savedLooks.isEmpty()) {
        EmptyState(modifier = modifier.fillMaxSize())
    } else {
        LazyVerticalGrid(
            columns = GridCells.Adaptive(minSize = 150.dp),
            modifier = modifier.fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            items(savedLooks) { look ->
                SavedLookCard(
                    look = look,
                    onClick = { onLookClick(look) },
                    onDelete = { onDeleteClick(look) }
                )
            }
        }
    }
}

@Composable
private fun EmptyState(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier,
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text(
                text = "No Saved Looks Yet",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )

            Text(
                text = "Capture your first look to see it here!",
                style = MaterialTheme.typography.bodyMedium,
                color = Color.Gray
            )
        }
    }
}

@Composable
private fun SavedLookCard(
    look: SavedLook,
    onClick: () -> Unit,
    onDelete: () -> Unit
) {
    var showDeleteDialog by remember { mutableStateOf(false) }

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .aspectRatio(1f)
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(12.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Box {
            // Thumbnail
            AsyncImage(
                model = look.resultImage,
                contentDescription = "Saved look",
                modifier = Modifier.fillMaxSize(),
                contentScale = androidx.compose.ui.layout.ContentScale.Crop
            )

            // Delete button
            IconButton(
                onClick = { showDeleteDialog = true },
                modifier = Modifier.align(Alignment.TopEnd)
            ) {
                Icon(
                    imageVector = Icons.Default.Delete,
                    contentDescription = "Delete",
                    tint = Color.White
                )
            }
        }
    }

    // Delete confirmation dialog
    if (showDeleteDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteDialog = false },
            title = { Text("Delete Look?") },
            text = { Text("Are you sure you want to delete this saved look?") },
            confirmButton = {
                TextButton(onClick = {
                    onDelete()
                    showDeleteDialog = false
                }) {
                    Text("Delete", color = Color.Red)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}

/**
 * Detailed view of a saved look with before/after comparison.
 */
@Composable
fun SavedLookDetail(
    look: SavedLook,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(modifier = modifier.fillMaxSize()) {
        // Top bar
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            TextButton(onClick = onBack) {
                Text("← Back", color = Color.White)
            }

            Text(
                text = look.getFormattedTimestamp(),
                style = MaterialTheme.typography.titleMedium,
                color = Color.White
            )
        }

        // Before/After comparison
        BeforeAfterComparison(
            beforeImage = loadBitmapFromUri(look.originalImage),
            afterImage = loadBitmapFromUri(look.resultImage),
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
        )

        // Applied filters info
        if (look.appliedFilters.isNotEmpty()) {
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                colors = CardDefaults.cardColors(
                    containerColor = Color.White.copy(alpha = 0.1f)
                )
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        text = "Applied Filters:",
                        style = MaterialTheme.typography.titleMedium,
                        color = Color.White
                    )

                    look.getFilterNames().forEach { filterName ->
                        Text(
                            text = "• $filterName",
                            style = MaterialTheme.typography.bodyMedium,
                            color = Color.Gray,
                            modifier = Modifier.padding(start = 16.dp)
                        )
                    }
                }
            }
        }
    }
}

// Helper function to load bitmap from URI (simplified)
private fun loadBitmapFromUri(uri: Uri): android.graphics.Bitmap {
    // In a real implementation, you would use ContentResolver to load the bitmap
    // For now, return a placeholder
    return android.graphics.Bitmap.createBitmap(100, 100, android.graphics.Bitmap.Config.ARGB_8888)
}
