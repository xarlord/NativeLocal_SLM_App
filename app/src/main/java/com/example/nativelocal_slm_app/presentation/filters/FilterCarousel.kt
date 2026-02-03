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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.example.nativelocal_slm_app.domain.model.FilterCategory
import com.example.nativelocal_slm_app.domain.model.FilterEffect
import com.example.nativelocal_slm_app.domain.model.PredefinedFilters

/**
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

/**
 * Bottom sheet for selecting filters.
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
        CategoryTabs(
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

@Composable
private fun CategoryTabs(
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

@Composable
private fun FilterGrid(
    category: FilterCategory,
    onFilterSelected: (FilterEffect) -> Unit
) {
    val filters = remember(category) {
        PredefinedFilters.getFiltersByCategory(category)
    }

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        filters.forEach { filter ->
            FilterGridItem(
                filter = filter,
                onClick = { onFilterSelected(filter) }
            )
        }
    }
}

@Composable
private fun FilterGridItem(
    filter: FilterEffect,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .height(80.dp)
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(
            containerColor = Color.White.copy(alpha = 0.1f)
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Thumbnail
            Box(
                modifier = Modifier
                    .size(56.dp)
                    .clip(CircleShape)
                    .background(Color.Gray),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = filter.name.first().toString(),
                    style = MaterialTheme.typography.titleMedium,
                    color = Color.White
                )
            }

            Spacer(modifier = Modifier.width(16.dp))

            // Filter info
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = filter.name,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White
                )
                Text(
                    text = filter.category.name.replace("_", " "),
                    style = MaterialTheme.typography.bodySmall,
                    color = Color.Gray
                )
            }
        }
    }
}
