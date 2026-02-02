package com.example.nativelocal_slm_app.presentation.filters

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.example.nativelocal_slm_app.domain.model.HairAccessory
import com.example.nativelocal_slm_app.domain.model.HairStyleSelection
import com.example.nativelocal_slm_app.domain.model.LengthPreset

/**
 * Bottom sheet for selecting hair style simulations.
 */
@Composable
fun StyleSelectionSheet(
    onStyleSelected: (HairStyleSelection) -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .fillMaxHeight(0.6f)
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
                text = "Hair Styles",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )

            TextButton(onClick = onDismiss) {
                Text("Close", color = Color.White)
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Length presets
        Text(
            text = "Length",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = Color.White
        )

        Spacer(modifier = Modifier.height(8.dp))

        LengthPreset.values().forEach { preset ->
            LengthOption(
                preset = preset,
                onClick = {
                    onStyleSelected(HairStyleSelection.Length(preset))
                    onDismiss()
                }
            )
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Accessories
        Text(
            text = "Accessories",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = Color.White
        )

        Spacer(modifier = Modifier.height(8.dp))

        HairAccessory.values().forEach { accessory ->
            AccessoryOption(
                accessory = accessory,
                onClick = {
                    onStyleSelected(HairStyleSelection.Accessory(accessory))
                    onDismiss()
                }
            )
        }
    }
}

@Composable
private fun LengthOption(
    preset: LengthPreset,
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
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = preset.displayName,
                style = MaterialTheme.typography.bodyLarge,
                color = Color.White
            )

            Text(
                text = preset.description,
                style = MaterialTheme.typography.bodySmall,
                color = Color.Gray
            )
        }
    }
}

@Composable
private fun AccessoryOption(
    accessory: HairAccessory,
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
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = accessory.displayName,
                style = MaterialTheme.typography.bodyLarge,
                color = Color.White
            )
        }
    }
}
