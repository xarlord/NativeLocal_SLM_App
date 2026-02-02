package com.example.nativelocal_slm_app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.zIndex

/**
 * iOS-style bottom sheet with rounded corners and backdrop.
 */
@Composable
fun iOSBottomSheet(
    isVisible: Boolean,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit
) {
    if (isVisible) {
        Dialog(
            onDismissRequest = onDismiss,
            properties = DialogProperties(
                dismissOnBackPress = true,
                dismissOnClickOutside = true,
                usePlatformDefaultWidth = false
            )
        ) {
            // Backdrop
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .testTag("BottomSheetBackdrop")
                    .background(Color.Black.copy(alpha = 0.4f))
                    .pointerInput(Unit) {
                        detectTapGestures {
                            onDismiss()
                        }
                    }
            ) {
                // Sheet content
                Surface(
                    modifier = modifier
                        .align(androidx.compose.ui.Alignment.BottomCenter)
                        .fillMaxWidth()
                        .pointerInput(Unit) {
                            // Consume taps to prevent dismissing through the sheet
                            detectTapGestures { }
                        },
                    shape = RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp),
                    color = Color.Black,
                    tonalElevation = 16.dp
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("BottomSheetContent")
                            .padding(16.dp)
                    ) {
                        // Handle bar
                        HandleBar()

                        Spacer(modifier = Modifier.height(16.dp))

                        // Content
                        content()
                    }
                }
            }
        }
    }
}

/**
 * Handle bar for indicating swipeable bottom sheet.
 */
@Composable
private fun HandleBar() {
    Box(
        modifier = Modifier
            .testTag("HandleBar")
            .width(36.dp)
            .height(5.dp)
            .background(
                Color.Gray.copy(alpha = 0.5f),
                RoundedCornerShape(2.5.dp)
            )
    )
}

/**
 * iOS-style half-height bottom sheet.
 */
@Composable
fun iOSHalfSheet(
    isVisible: Boolean,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit
) {
    if (isVisible) {
        Dialog(
            onDismissRequest = onDismiss,
            properties = DialogProperties(
                dismissOnBackPress = true,
                dismissOnClickOutside = true,
                usePlatformDefaultWidth = false
            )
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .testTag("BottomSheetBackdrop")
                    .background(Color.Black.copy(alpha = 0.4f))
                    .pointerInput(Unit) {
                        detectTapGestures {
                            onDismiss()
                        }
                    }
            ) {
                Surface(
                    modifier = modifier
                        .align(androidx.compose.ui.Alignment.BottomCenter)
                        .fillMaxWidth()
                        .fillMaxHeight(0.6f)
                        .pointerInput(Unit) {
                            detectTapGestures { }
                        },
                    shape = RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp),
                    color = Color.Black,
                    tonalElevation = 16.dp
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .testTag("BottomSheetContent")
                            .padding(16.dp)
                    ) {
                        HandleBar()
                        Spacer(modifier = Modifier.height(16.dp))
                        content()
                    }
                }
            }
        }
    }
}
