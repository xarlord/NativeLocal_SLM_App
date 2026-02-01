package com.example.nativelocal_slm_app.presentation.results

import android.graphics.Bitmap
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.ClipOp
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.zIndex

/**
 * Before/After comparison slider with drag handle.
 */
@Composable
fun BeforeAfterComparison(
    beforeImage: Bitmap,
    afterImage: Bitmap,
    modifier: Modifier = Modifier,
    initialPosition: Float = 0.5f
) {
    var sliderPosition by remember { mutableStateOf(initialPosition) }

    Box(
        modifier = modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        // Before image (background - shows on the right)
        Image(
            bitmap = beforeImage.asImageBitmap(),
            contentDescription = "Before",
            modifier = Modifier.fillMaxSize()
        )

        // After image (foreground - clipped and shows on the left)
        Canvas(
            modifier = Modifier
                .fillMaxSize()
                .zIndex(1f)
        ) {
            val width = size.width
            val clipX = width * sliderPosition

            clipPath(
                path = Path().apply {
                    addRect(
                        androidx.compose.ui.geometry.Rect(
                            left = 0f,
                            top = 0f,
                            right = clipX,
                            bottom = size.height
                        )
                    )
                },
                clipOp = ClipOp.Intersect
            ) {
                drawImage(
                    image = afterImage.asImageBitmap(),
                    dstSize = IntSize(
                        width.toInt(),
                        size.height.toInt()
                    )
                )
            }
        }

        // Divider line
        Canvas(
            modifier = Modifier
                .fillMaxSize()
                .zIndex(2f)
                .pointerInput(Unit) {
                    detectHorizontalDragGestures { _, dragAmount ->
                        val newPosition = sliderPosition + dragAmount / size.width
                        sliderPosition = newPosition.coerceIn(0f, 1f)
                    }
                }
        ) {
            val lineX = size.width * sliderPosition

            // Draw vertical line
            drawLine(
                color = Color.White,
                start = Offset(lineX, 0f),
                end = Offset(lineX, size.height),
                strokeWidth = 4f
            )

            // Draw circle handle at center
            drawCircle(
                color = Color.White,
                radius = 24f,
                center = Offset(lineX, size.height / 2f)
            )

            // Draw black border around circle
            drawCircle(
                color = Color.Black,
                radius = 26f,
                center = Offset(lineX, size.height / 2f),
                style = androidx.compose.ui.graphics.drawscope.Stroke(
                    width = 4f
                )
            )

            // Draw arrows
            val textPaint = android.graphics.Paint().apply {
                color = android.graphics.Color.BLACK
                textSize = 32f
                textAlign = android.graphics.Paint.Align.CENTER
            }

            drawContext.canvas.nativeCanvas.drawText(
                "◀",
                lineX,
                size.height / 2 + 10f,
                textPaint
            )
        }

        // Labels
        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp)
                .zIndex(3f),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(
                text = "After",
                style = MaterialTheme.typography.titleLarge,
                color = Color.White,
                modifier = Modifier
                    .background(Color.Black.copy(alpha = 0.5f))
                    .padding(8.dp)
            )

            Text(
                text = "Before",
                style = MaterialTheme.typography.titleLarge,
                color = Color.White,
                modifier = Modifier
                    .background(Color.Black.copy(alpha = 0.5f))
                    .padding(8.dp)
            )
        }
    }
}
