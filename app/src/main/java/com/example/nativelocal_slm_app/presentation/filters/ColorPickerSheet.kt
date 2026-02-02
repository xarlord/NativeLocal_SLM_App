package com.example.nativelocal_slm_app.presentation.filters

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.example.nativelocal_slm_app.ui.animation.HairColorSwatch
import com.example.nativelocal_slm_app.ui.animation.PredefinedHairColors

/**
 * Bottom sheet for selecting hair colors.
 */
@Composable
fun ColorPickerSheet(
    onColorSelected: (Color) -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(
                Color.Black.copy(alpha = 0.95f),
                RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp)
            )
            .padding(16.dp)
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Hair Color",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )

            TextButton(onClick = onDismiss) {
                Text("Close", color = Color.White)
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Predefined color swatches
        Text(
            text = "Predefined Colors",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = Color.White
        )

        Spacer(modifier = Modifier.height(12.dp))

        ColorSwatchGrid(
            colors = PredefinedHairColors.getAllColors(),
            onColorSelected = {
                onColorSelected(it)
                onDismiss()
            }
        )
    }
}

@Composable
private fun ColorSwatchGrid(
    colors: List<HairColorSwatch>,
    onColorSelected: (Color) -> Unit
) {
    LazyRow(
        horizontalArrangement = Arrangement.spacedBy(16.dp),
        contentPadding = PaddingValues(horizontal = 8.dp)
    ) {
        items(colors) { swatch ->
            ColorSwatch(
                color = swatch.color,
                name = swatch.name,
                onClick = { onColorSelected(swatch.color) }
            )
        }
    }
}

@Composable
private fun ColorSwatch(
    color: Color,
    name: String,
    onClick: () -> Unit
) {
    var isPressed by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .clickable(onClick = onClick)
            .padding(8.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            modifier = Modifier
                .size(64.dp)
                .clip(CircleShape)
                .background(color)
                .then(
                    if (isPressed) {
                        Modifier.clip(CircleShape).background(Color.White.copy(alpha = 0.3f))
                    } else {
                        Modifier
                    }
                )
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = name,
            style = MaterialTheme.typography.labelSmall,
            color = Color.White
        )
    }
}
