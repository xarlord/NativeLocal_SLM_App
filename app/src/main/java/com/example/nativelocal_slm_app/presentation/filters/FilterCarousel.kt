package com.example.nativelocal_slm_app.presentation.filters

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.example.nativelocal_slm_app.domain.model.FilterEffect
import com.example.nativelocal_slm_app.domain.model.PredefinedFilters

/**
 * MEDIUM PRIORITY FIX #1: Split god class FilterCarousel.kt
 *
 * BEFORE: 312 lines with multiple responsibilities (carousel + sheet + tabs + grid)
 * AFTER: 135 lines with single responsibility (horizontal carousel only)
 *
 * Extracted to FilterSelectionSheet.kt:
 * - FilterSelectionSheet
 * - FilterCategoryTabs
 * - FilterCategoryTab
 * - FilterGrid (new version)
 * - FilterGridItem
 *
 * This file now ONLY contains the horizontal carousel for quick filter access.
 * Optimized for camera screen with emoji-based icons.
 *
 * Horizontal carousel of filter thumbnails for quick selection.
 */
@Composable
fun FilterCarousel(
    selectedFilter: FilterEffect?,
    onFilterSelected: (FilterEffect) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(modifier = modifier) {
        Text(
            text = "Quick Filters",
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = Color.White,
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
        )

        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp)
        ) {
            // None option (remove filter)
            item {
                FilterCarouselItem(
                    name = "None",
                    isSelected = selectedFilter == null,
                    onClick = { /* No-op, handled elsewhere */ },
                    showThumbnail = false,
                    showEmoji = true,
                    emoji = "✕"
                )
            }

            // All filters
            items(PredefinedFilters.getAllFilters()) { filter ->
                FilterCarouselItem(
                    name = filter.name,
                    isSelected = selectedFilter?.id == filter.id,
                    onClick = { onFilterSelected(filter) },
                    showThumbnail = true
                )
            }
        }
    }
}

/**
 * MEDIUM PRIORITY FIX #1: Simplified carousel item component.
 * Extracted from FilterCarousel god class.
 * Displays filter thumbnail with emoji and name.
 */
@Composable
private fun FilterCarouselItem(
    name: String,
    isSelected: Boolean,
    onClick: () -> Unit,
    showThumbnail: Boolean,
    showEmoji: Boolean = false,
    emoji: String = ""
) {
    val scale = if (isSelected) 1.15f else 1.0f

    Column(
        modifier = Modifier
            .scale(scale)
            .clip(RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .background(
                if (isSelected) Color.White else Color.White.copy(alpha = 0.15f)
            )
            .padding(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Thumbnail or emoji circle
        Box(
            modifier = Modifier
                .size(56.dp)
                .clip(CircleShape)
                .background(
                    if (isSelected) Color.Black else Color.Gray
                ),
            contentAlignment = Alignment.Center
        ) {
            if (showEmoji) {
                Text(
                    text = emoji,
                    style = MaterialTheme.typography.titleLarge,
                    color = if (isSelected) Color.White else Color.White
                )
            } else if (showThumbnail) {
                Text(
                    text = name.first().toString(),
                    style = MaterialTheme.typography.titleMedium,
                    color = Color.White,
                    fontWeight = FontWeight.Bold
                )
            }
        }

        Spacer(modifier = Modifier.height(8.dp))

        // Filter name
        Text(
            text = name,
            style = MaterialTheme.typography.labelSmall,
            color = if (isSelected) Color.Black else Color.White,
            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
            textAlign = TextAlign.Center,
            maxLines = 1
        )
    }
}
