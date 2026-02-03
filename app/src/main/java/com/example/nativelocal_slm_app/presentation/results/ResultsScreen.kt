package com.example.nativelocal_slm_app.presentation.results

import android.content.Context
import android.content.Intent
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import com.example.nativelocal_slm_app.data.model.SavedLook
import com.example.nativelocal_slm_app.domain.usecase.SaveLookUseCase
import com.example.nativelocal_slm_app.presentation.camera.CapturedPhoto
import kotlinx.coroutines.launch
import java.io.File

/**
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
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var savedLook by remember { mutableStateOf<SavedLook?>(null) }
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
                    shareImage(context, capturedPhoto.processedImage)
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
                // Handle loading a saved look
                showHistory = false
            }
        )
    }
}

@Composable
private fun ResultsTopBar(
    onBack: () -> Unit,
    onShowHistory: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(56.dp)
            .background(Color.Black)
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        IconButton(onClick = onBack) {
            Icon(
                imageVector = Icons.Filled.ArrowBack,
                contentDescription = "Back",
                tint = Color.White
            )
        }

        Text(
            text = "Results",
            style = MaterialTheme.typography.titleLarge,
            color = Color.White
        )

        IconButton(onClick = onShowHistory) {
            Icon(
                imageVector = Icons.Filled.History,
                contentDescription = "History",
                tint = Color.White
            )
        }
    }
}

@Composable
private fun ResultsActions(
    onSave: () -> Unit,
    onShare: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Button(
            onClick = onSave,
            modifier = Modifier.weight(1f),
            colors = ButtonDefaults.buttonColors(
                containerColor = Color.White
            )
        ) {
            Icon(
                imageVector = Icons.Filled.Download,
                contentDescription = null,
                tint = Color.Black,
                modifier = Modifier.size(20.dp)
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text("Save", color = Color.Black)
        }

        Button(
            onClick = onShare,
            modifier = Modifier.weight(1f),
            colors = ButtonDefaults.buttonColors(
                containerColor = Color.White
            )
        ) {
            Icon(
                imageVector = Icons.Filled.Share,
                contentDescription = null,
                tint = Color.Black,
                modifier = Modifier.size(20.dp)
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text("Share", color = Color.Black)
        }
    }
}

@Composable
private fun HistoryDrawer(
    onClose: () -> Unit,
    onLookSelected: (SavedLook) -> Unit
) {
    var savedLooks by remember { mutableStateOf<List<SavedLook>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }

    LaunchedEffect(Unit) {
        // In a real implementation, load saved looks from SaveLookUseCase
        savedLooks = emptyList()
        isLoading = false
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.95f))
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            // Header
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Saved Looks",
                    style = MaterialTheme.typography.titleLarge,
                    color = Color.White
                )

                TextButton(onClick = onClose) {
                    Text("Close", color = Color.White)
                }
            }

            // Content
            if (isLoading) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(color = Color.White)
                }
            } else {
                PhotoHistoryGrid(
                    savedLooks = savedLooks,
                    onLookClick = onLookSelected,
                    onDeleteClick = { /* Handle delete */ }
                )
            }
        }
    }
}

/**
 * Share an image using Android's share intent.
 */
private fun shareImage(context: Context, bitmap: android.graphics.Bitmap) {
    // Save bitmap to cache
    val cachePath = File(context.externalCacheDir, "shared_image.jpg")
    cachePath.delete()
    java.io.FileOutputStream(cachePath).use { stream ->
        bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 90, stream)
    }

    // Create URI using FileProvider
    val uri = FileProvider.getUriForFile(
        context,
        "${context.packageName}.fileprovider",
        cachePath
    )

    // Create share intent
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = "image/jpeg"
        putExtra(Intent.EXTRA_STREAM, uri)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }

    context.startActivity(Intent.createChooser(intent, "Share Image"))
}
