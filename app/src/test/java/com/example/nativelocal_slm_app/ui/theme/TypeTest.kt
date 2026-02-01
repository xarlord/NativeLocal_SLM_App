package com.example.nativelocal_slm_app.ui.theme

import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Unit tests for Type.kt typography constants.
 */
class TypeTest {

    @Test
    fun `Typography Large Title has correct properties`() {
        assertEquals("Large Title should use Bold font", FontWeight.Bold, Typography.titleLarge.fontWeight)
        assertEquals("Large Title should be 34sp", 34.sp, Typography.titleLarge.fontSize)
        assertEquals("Large Title line height should be 41sp", 41.sp, Typography.titleLarge.lineHeight)
        assertEquals("Large Title letter spacing should be 0", 0.sp, Typography.titleLarge.letterSpacing)
        assertEquals("Large Title should use default font family", FontFamily.Default, Typography.titleLarge.fontFamily)
    }

    @Test
    fun `Typography Title1 has correct properties`() {
        assertEquals("Title1 should use Bold font", FontWeight.Bold, Typography.titleMedium.fontWeight)
        assertEquals("Title1 should be 28sp", 28.sp, Typography.titleMedium.fontSize)
        assertEquals("Title1 line height should be 34sp", 34.sp, Typography.titleMedium.lineHeight)
        assertEquals("Title1 letter spacing should be 0", 0.sp, Typography.titleMedium.letterSpacing)
    }

    @Test
    fun `Typography Title2 has correct properties`() {
        assertEquals("Title2 should use Bold font", FontWeight.Bold, Typography.titleSmall.fontWeight)
        assertEquals("Title2 should be 22sp", 22.sp, Typography.titleSmall.fontSize)
        assertEquals("Title2 line height should be 28sp", 28.sp, Typography.titleSmall.lineHeight)
        assertEquals("Title2 letter spacing should be 0", 0.sp, Typography.titleSmall.letterSpacing)
    }

    @Test
    fun `Typography Headline has correct properties`() {
        assertEquals("Headline should use Semibold font", FontWeight.SemiBold, Typography.headlineLarge.fontWeight)
        assertEquals("Headline should be 17sp", 17.sp, Typography.headlineLarge.fontSize)
        assertEquals("Headline line height should be 22sp", 22.sp, Typography.headlineLarge.lineHeight)
        assertEquals("Headline letter spacing should be negative", (-0.43).sp, Typography.headlineLarge.letterSpacing)
    }

    @Test
    fun `Typography Body has correct properties`() {
        assertEquals("Body should use Normal font", FontWeight.Normal, Typography.bodyLarge.fontWeight)
        assertEquals("Body should be 17sp", 17.sp, Typography.bodyLarge.fontSize)
        assertEquals("Body line height should be 22sp", 22.sp, Typography.bodyLarge.lineHeight)
        assertEquals("Body letter spacing should be negative", (-0.43).sp, Typography.bodyLarge.letterSpacing)
    }

    @Test
    fun `Typography Callout has correct properties`() {
        assertEquals("Callout should use Normal font", FontWeight.Normal, Typography.bodyMedium.fontWeight)
        assertEquals("Callout should be 16sp", 16.sp, Typography.bodyMedium.fontSize)
        assertEquals("Callout line height should be 21sp", 21.sp, Typography.bodyMedium.lineHeight)
        assertEquals("Callout letter spacing should be negative", (-0.32).sp, Typography.bodyMedium.letterSpacing)
    }

    @Test
    fun `Typography Subheadline has correct properties`() {
        assertEquals("Subheadline should use Normal font", FontWeight.Normal, Typography.bodySmall.fontWeight)
        assertEquals("Subheadline should be 15sp", 15.sp, Typography.bodySmall.fontSize)
        assertEquals("Subheadline line height should be 20sp", 20.sp, Typography.bodySmall.lineHeight)
        assertEquals("Subheadline letter spacing should be negative", (-0.24).sp, Typography.bodySmall.letterSpacing)
    }

    @Test
    fun `Typography Footnote has correct properties`() {
        assertEquals("Footnote should use Normal font", FontWeight.Normal, Typography.labelLarge.fontWeight)
        assertEquals("Footnote should be 13sp", 13.sp, Typography.labelLarge.fontSize)
        assertEquals("Footnote line height should be 18sp", 18.sp, Typography.labelLarge.lineHeight)
        assertEquals("Footnote letter spacing should be slightly negative", (-0.08).sp, Typography.labelLarge.letterSpacing)
    }

    @Test
    fun `Typography Caption1 has correct properties`() {
        assertEquals("Caption1 should use Normal font", FontWeight.Normal, Typography.labelMedium.fontWeight)
        assertEquals("Caption1 should be 12sp", 12.sp, Typography.labelMedium.fontSize)
        assertEquals("Caption1 line height should be 16sp", 16.sp, Typography.labelMedium.lineHeight)
        assertEquals("Caption1 letter spacing should be 0", 0.sp, Typography.labelMedium.letterSpacing)
    }

    @Test
    fun `Typography Caption2 has correct properties`() {
        assertEquals("Caption2 should use Normal font", FontWeight.Normal, Typography.labelSmall.fontWeight)
        assertEquals("Caption2 should be 11sp", 11.sp, Typography.labelSmall.fontSize)
        assertEquals("Caption2 line height should be 13sp", 13.sp, Typography.labelSmall.lineHeight)
        assertEquals("Caption2 letter spacing should be positive", 0.06.sp, Typography.labelSmall.letterSpacing)
    }

    @Test
    fun `all typography styles use default font family`() {
        val styles = listOf(
            Typography.titleLarge, Typography.titleMedium, Typography.titleSmall,
            Typography.headlineLarge, Typography.bodyLarge, Typography.bodyMedium,
            Typography.bodySmall, Typography.labelLarge, Typography.labelMedium, Typography.labelSmall
        )

        styles.forEach { style ->
            assertEquals("All styles should use default font family", FontFamily.Default, style.fontFamily)
        }
    }

    @Test
    fun `font sizes decrease appropriately from Large Title to Caption2`() {
        assertTrue("Large Title should be larger than Title1", Typography.titleLarge.fontSize.value > Typography.titleMedium.fontSize.value)
        assertTrue("Title1 should be larger than Title2", Typography.titleMedium.fontSize.value > Typography.titleSmall.fontSize.value)
        assertTrue("Headline should be larger than Body", Typography.headlineLarge.fontSize.value >= Typography.bodyLarge.fontSize.value)
        assertTrue("Body should be larger than Caption2", Typography.bodyLarge.fontSize.value > Typography.labelSmall.fontSize.value)
    }

    @Test
    fun `iOSTextStyles object is defined`() {
        // Verify the iOSTextStyles object exists
        assertNotNull("iOSTextStyles should be defined", iOSTextStyles)
    }
}
