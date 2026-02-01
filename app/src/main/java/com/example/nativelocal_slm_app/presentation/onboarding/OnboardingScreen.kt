package com.example.nativelocal_slm_app.presentation.onboarding

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowForward
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex

/**
 * Onboarding screen with multiple pages explaining app features.
 */
@Composable
fun OnboardingScreen(
    onComplete: () -> Unit,
    modifier: Modifier = Modifier
) {
    var currentPage by remember { mutableStateOf(0) }
    val pages = remember { OnboardingPage.values().toList() }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        // Page content
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            val page = pages[currentPage]

            Spacer(modifier = Modifier.height(48.dp))

            // Icon/illustration placeholder
            OnboardingIcon(page = page)

            Spacer(modifier = Modifier.height(32.dp))

            // Title
            Text(
                text = page.title,
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                textAlign = TextAlign.Center
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Description
            Text(
                text = page.description,
                style = MaterialTheme.typography.bodyLarge,
                color = Color.Gray,
                textAlign = TextAlign.Center
            )

            Spacer(modifier = Modifier.weight(1f))

            // Page indicators
            PageIndicators(
                totalPages = pages.size,
                currentPage = currentPage,
                modifier = Modifier.padding(vertical = 24.dp)
            )

            // Action button
            Button(
                onClick = {
                    if (currentPage < pages.size - 1) {
                        currentPage++
                    } else {
                        onComplete()
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                shape = RoundedCornerShape(28.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color.White
                )
            ) {
                Text(
                    text = if (currentPage < pages.size - 1) "Next" else "Get Started",
                    color = Color.Black,
                    fontWeight = FontWeight.Bold
                )

                if (currentPage < pages.size - 1) {
                    Spacer(modifier = Modifier.width(8.dp))
                    Icon(
                        imageVector = Icons.Default.ArrowForward,
                        contentDescription = null,
                        tint = Color.Black
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Skip button
            if (currentPage < pages.size - 1) {
                TextButton(onClick = onComplete) {
                    Text(
                        text = "Skip",
                        color = Color.Gray,
                        fontWeight = FontWeight.Medium
                    )
                }
            }
        }
    }
}

@Composable
private fun OnboardingIcon(page: OnboardingPage) {
    Box(
        modifier = Modifier
            .size(200.dp)
            .clip(CircleShape)
            .background(Color.White.copy(alpha = 0.1f)),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = page.emoji,
            style = MaterialTheme.typography.displayLarge
        )
    }
}

@Composable
private fun PageIndicators(
    totalPages: Int,
    currentPage: Int,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        repeat(totalPages) { index ->
            PageIndicator(
                isActive = index == currentPage,
                modifier = Modifier
                    .width(if (index == currentPage) 24.dp else 8.dp)
                    .height(8.dp)
            )
        }
    }
}

@Composable
private fun PageIndicator(
    isActive: Boolean,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .testTag("PageIndicator")
            .clip(RoundedCornerShape(4.dp))
            .background(
                if (isActive) Color.White else Color.White.copy(alpha = 0.3f)
            )
    )
}

/**
 * Onboarding pages.
 */
enum class OnboardingPage(
    val title: String,
    val description: String,
    val emoji: String
) {
    WELCOME(
        title = "Welcome to Hair Analysis",
        description = "Discover your hair type, color, and style with our advanced AI-powered analysis.",
        emoji = "💇"
    ),
    CAMERA(
        title = "Real-Time Analysis",
        description = "Point your camera at yourself to see instant hair segmentation and style recommendations.",
        emoji = "📸"
    ),
    FILTERS(
        title = "Try New Styles",
        description = "Experiment with filters, colors, and hairstyles before making any real changes.",
        emoji = "🎨"
    ),
    SAVE_SHARE(
        title = "Save & Share",
        description = "Capture your favorite looks and share them with friends or on social media.",
        emoji = "📱"
    )
}
