package com.example.nativelocal_slm_app.domain.usecase

import android.media.Image
import androidx.camera.core.ImageProxy
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.example.nativelocal_slm_app.domain.repository.HairAnalysisRepository
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Instrumented tests for ProcessCameraFrameUseCase.
 * These tests require real Android environment for ImageProxy operations.
 */
@RunWith(AndroidJUnit4::class)
@OptIn(ExperimentalCoroutinesApi::class)
class ProcessCameraFrameUseCaseTest {

    private lateinit var useCase: ProcessCameraFrameUseCase
    private val repository: HairAnalysisRepository = mockk(relaxed = true)
    private val testDispatcher = UnconfinedTestDispatcher()

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        useCase = ProcessCameraFrameUseCase(repository)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun invoke_returnsNull_whenImageIsNull() = runTest {
        val imageProxy = mockk<ImageProxy>()
        every { imageProxy.image } returns null

        val result = useCase.invoke(imageProxy)

        assert(result == null)
    }

    @Test
    fun invoke_returnsNull_whenRepositoryThrowsException() = runTest {
        val imageProxy = mockk<ImageProxy>()
        every { imageProxy.image } returns mockk<Image>()
        every { imageProxy.width } returns 100
        every { imageProxy.height } returns 100

        coEvery { repository.analyzeHair(any()) } throws RuntimeException("Test error")

        val result = useCase.invoke(imageProxy)

        assert(result == null)
    }

    @Test
    fun invoke_closesImageProxy_evenOnException() = runTest {
        val imageProxy = mockk<ImageProxy>(relaxed = true)
        every { imageProxy.image } returns mockk<Image>()
        every { imageProxy.width } returns 100
        every { imageProxy.height } returns 100

        coEvery { repository.analyzeHair(any()) } throws RuntimeException("Test error")

        useCase.invoke(imageProxy)

        // Verify close was called (relaxed mock tracks calls)
        coVerify { imageProxy.close() }
    }
}
