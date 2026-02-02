package com.example.nativelocal_slm_app

/**
 * Utility functions for safer test assertions.
 * HIGH PRIORITY FIX #4: Replaces unsafe !! operators with proper null checks.
 *
 * Usage:
 * Instead of: result.segmentationMask!!.width
 * Use: requireNotNull(result.segmentationMask, "segmentationMask").width
 *
 * Or use helper methods:
 * assertNotNull(result.segmentationMask) { mask -> mask.width }
 */

/**
 * Assert that a value is not null and provide it to a block.
 * Provides clear error messages when null checks fail.
 */
inline fun <T : Any> assertNotNullNotNull(
    value: T?,
    message: String = "Value should not be null",
    block: (T) -> Unit
) {
    if (value == null) {
        throw AssertionError("$message: was null")
    }
    block(value)
}

/**
 * Assert that a Bitmap is not null and has expected dimensions.
 */
fun assertBitmapDimensions(
    bitmap: android.graphics.Bitmap?,
    expectedWidth: Int,
    expectedHeight: Int,
    message: String = "Bitmap"
) {
    assertNotNull(bitmap, "$message should not be null")
    assertEquals(expectedWidth, bitmap.width, "$message width should match")
    assertEquals(expectedHeight, bitmap.height, "$message height should match")
}

/**
 * Assert that a segmentation mask exists and has expected properties.
 */
fun assertSegmentationMask(
    mask: android.graphics.Bitmap?,
    expectedWidth: Int,
    expectedHeight: Int
) {
    assertNotNull(mask, "segmentationMask should not be null")
    assertEquals(expectedWidth, mask.width, "segmentationMask width")
    assertEquals(expectedHeight, mask.height, "segmentationMask height")
}

/**
 * Assert that face landmarks exist and have valid properties.
 */
fun assertFaceLandmarks(
    landmarks: com.example.nativelocal_slm_app.domain.model.FaceLandmarksResult?,
    message: String = "faceLandmarks"
) {
    assertNotNull(landmarks, "$message should not be null")
    assertTrue(landmarks.confidence > 0, "$message confidence should be positive")
    assertTrue(landmarks.boundingBox.left >= 0, "$message boundingBox left should be non-negative")
}

/**
 * Helper to create test bitmap with null safety.
 */
fun createTestBitmap(width: Int, height: Int): android.graphics.Bitmap {
    return android.graphics.Bitmap.createBitmap(width, height, android.graphics.Bitmap.Config.ARGB_8888)
}

/**
 * JUnit-style assertNotNull with message.
 */
fun <T : Any> assertNotNull(
    value: T?,
    message: String
): T {
    org.junit.Assert.assertNotNull(message, value)
    return value!!
}

/**
 * JUnit-style assertTrue with message.
 */
fun assertTrue(
    condition: Boolean,
    message: String
) {
    org.junit.Assert.assertTrue(message, condition)
}

/**
 * JUnit-style assertEquals with message.
 */
fun <T> assertEquals(
    expected: T,
    actual: T,
    message: String
) {
    org.junit.Assert.assertEquals(message, expected, actual)
}
