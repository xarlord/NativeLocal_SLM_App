package com.example.nativelocal_slm_app.presentation.filters

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.example.nativelocal_slm_app.domain.model.FilterCategory
import com.example.nativelocal_slm_app.domain.model.FilterEffect

/**
 * MEDIUM PRIORITY FIX #1: Split god class FilterCarousel.kt
 * Extracted FilterSelectionSheet into separate file for better organization.
 *
 * Bottom sheet for selecting filters with category tabs.
 */
@Composable
fun FilterSelectionSheet(
    onFilterSelected: (FilterEffect) -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier
) {
    var selectedCategory by remember { mutableStateOf(FilterCategory.FACE) }

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
                text = "Select Filter",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )

            TextButton(onClick = onDismiss) {
                Text("Close", color = Color.White)
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Category tabs
        FilterCategoryTabs(
            selectedCategory = selectedCategory,
            onCategorySelected = { selectedCategory = it }
        )

        Spacer(modifier = Modifier.height(16.dp))

        // Filter grid for selected category
        FilterGrid(
            category = selectedCategory,
            onFilterSelected = {
                onFilterSelected(it)
                onDismiss()
            }
        )
    }
}

/**
 * Category tabs for filter selection.
 */
@Composable
private fun FilterCategoryTabs(
    selectedCategory: FilterCategory,
    onCategorySelected: (FilterCategory) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        FilterCategory.values().forEach { category ->
            FilterCategoryTab(
                category = category,
                isSelected = selectedCategory == category,
                onClick = { onCategorySelected(category) },
                modifier = Modifier.weight(1f)
            )
        }
    }
}

/**
 * Individual category tab button.
 */
@Composable
private fun FilterCategoryTab(
    category: FilterCategory,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Button(
        onClick = { onClick() },
        modifier = modifier.height(40.dp),
        shape = RoundedCornerShape(20.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = if (isSelected) Color.White else Color.Gray,
            contentColor = if (isSelected) Color.Black else Color.White
        )
    ) {
        Text(
            text = category.name.replace("_", " "),
            style = MaterialTheme.typography.labelMedium
        )
    }
}

/**
 * Grid of filters for the selected category.
 */
@Composable
private fun FilterGrid(
    category: FilterCategory,
    onFilterSelected: (FilterEffect) -> Unit
) {
    val filters = com.example.nativelocal_slm_app.domain.model.PredefinedFilters.getFiltersByCategory(category)

    androidx.compose.foundation.lazy.grid.GridLazyVerticalColumns(
        columns = androidx.compose.foundation.lazy.grid.GridCells.Fixed(2),
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
        contentPadding = PaddingValues(vertical = 8.dp)
    ) {
        items(filters.size) { index ->
            FilterGridItem(
                filter = filters[index],
                onClick = { onFilterSelected(filters[index]) }
            )
        }
    }
}

/**
 * Individual filter grid item.
 */
@Composable
private fun FilterGridItem(
    filter: FilterEffect,
    onClick: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                Color.White.copy(alpha = 0.1f),
                RoundedCornerShape(12.dp)
            )
            .clickable(onClick = onClick)
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Emoji icon based on filter
        Text(
            text = getFilterEmoji(filter.id),
            style = MaterialTheme.typography.displaySmall,
            modifier = Modifier.padding(vertical = 8.dp)
        )

        Spacer(modifier = Modifier.height(8.dp))

        // Filter name
        Text(
            text = filter.name,
            style = MaterialTheme.typography.bodyMedium,
            color = Color.White,
            fontWeight = FontWeight.Medium
        )
    }
}

/**
 * Get emoji icon for a filter.
 */
private fun getFilterEmoji(filterId: String): String {
    return when (filterId) {
        "batman" -> "🦇"
        "joker" -> "🃏"
        "skeleton" -> "💀"
        "tiger_face" -> "🐯"
        "punk_mohawk" -> "🔺"
        "neon_glow" -> "✨"
        "fire_hair" -> "🔥"
        "wonder_woman" -> "👸"
        "harley_quinn" -> "💖"
        "cyberpunk" -> "🤖"
        else -> "✨"
    }
}
