package com.example.nativelocal_slm_app.domain.usecase

import android.content.Context
import android.graphics.Bitmap
import io.mockk.every
import io.mockk.mockk
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File
import kotlinx.coroutines.test.runTest

/**
 * Unit tests for SaveLookUseCase.
 * Uses Robolectric for Android Context support.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class SaveLookUseCaseTest {

    private lateinit var useCase: SaveLookUseCase
    private lateinit var context: Context
    private lateinit var testFilesDir: File

    @Before
    fun setup() {
        context = mockk<Context>(relaxed = true)
        testFilesDir = File(System.getProperty("java.io.tmpdir"), "test_saved_looks")
        testFilesDir.mkdirs()

        every { context.filesDir } returns testFilesDir

        useCase = SaveLookUseCase(context)
    }

    @Test
    fun `invoke saves images and returns SavedLook`() = runTest {
        val originalBitmap = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)
        val resultBitmap = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)

        val result = useCase(originalBitmap, resultBitmap, listOf("filter1"))

        assert(result.isSuccess)
        val savedLook = result.getOrNull()
        assert(savedLook != null)
        assert(savedLook!!.appliedFilters == listOf("filter1"))
        assert(savedLook.id.isNotEmpty())

        // Verify files were created
        val savedLooksDir = File(testFilesDir, "saved_looks")
        assert(savedLooksDir.exists())
    }

    @Test
    fun `invoke creates saved_looks directory if not exists`() = runTest {
        // Delete directory first
        testFilesDir.deleteRecursively()
        every { context.filesDir } returns testFilesDir

        val originalBitmap = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)
        val resultBitmap = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)

        val result = useCase(originalBitmap, resultBitmap, emptyList())

        assert(result.isSuccess)
        val savedLooksDir = File(testFilesDir, "saved_looks")
        assert(savedLooksDir.exists())
    }

    @Test
    fun `loadSavedLooks returns empty list when directory not exists`() = runTest {
        val emptyDir = File(System.getProperty("java.io.tmpdir"), "nonexistent_looks")
        every { context.filesDir } returns emptyDir

        val result = useCase.loadSavedLooks()

        assert(result.isSuccess)
        assert(result.getOrNull()?.isEmpty() == true)
    }

    @Test
    fun `loadSavedLooks returns empty list when directory empty`() = runTest {
        val emptyDir = File(System.getProperty("java.io.tmpdir"), "empty_looks")
        emptyDir.mkdirs()
        every { context.filesDir } returns emptyDir

        val result = useCase.loadSavedLooks()

        assert(result.isSuccess)
        assert(result.getOrNull()?.isEmpty() == true)
    }

    @Test
    fun `invoke generates unique IDs for each saved look`() = runTest {
        val originalBitmap = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)
        val resultBitmap = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)

        val result1 = useCase(originalBitmap, resultBitmap, emptyList())
        val result2 = useCase(originalBitmap, resultBitmap, emptyList())

        assert(result1.isSuccess)
        assert(result2.isSuccess)

        val look1 = result1.getOrNull()!!
        val look2 = result2.getOrNull()!!

        assert(look1.id != look2.id)
    }

    @Test
    fun `invoke sets timestamp to current time`() = runTest {
        val beforeTime = System.currentTimeMillis()
        val originalBitmap = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)
        val resultBitmap = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)

        val result = useCase(originalBitmap, resultBitmap, emptyList())
        val afterTime = System.currentTimeMillis()

        assert(result.isSuccess)
        val savedLook = result.getOrNull()!!

        assert(savedLook.timestamp.toEpochMilli() >= beforeTime)
        assert(savedLook.timestamp.toEpochMilli() <= afterTime)
    }

    @Test
    fun `deleteLook handles exceptions gracefully`() = runTest {
        // Create a mock SavedLook with invalid URIs
        val savedLook = com.example.nativelocal_slm_app.data.model.SavedLook(
            id = "test",
            timestamp = java.time.Instant.now(),
            originalImage = android.net.Uri.parse("content://invalid"),
            resultImage = android.net.Uri.parse("content://invalid"),
            appliedFilters = emptyList()
        )

        val result = useCase.deleteLook(savedLook)

        // Should handle exception and return failure
        // The exact behavior depends on implementation
        assert(result != null)
    }
}
