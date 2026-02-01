package com.example.nativelocal_slm_app.domain.usecase

import android.graphics.Bitmap
import com.example.nativelocal_slm_app.domain.repository.HairAnalysisRepository
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.Before
import org.junit.Test

/**
 * Unit tests for AnalyzeHairUseCase.
 */
class AnalyzeHairUseCaseTest {

    private lateinit var useCase: AnalyzeHairUseCase
    private val repository: HairAnalysisRepository = mockk(relaxed = true)

    @Before
    fun setup() {
        useCase = AnalyzeHairUseCase(repository)
    }

    @Test
    fun `invoke delegates to repository analyzeHair`() = runTest {
        val bitmap = mockk<Bitmap>()

        useCase.invoke(bitmap)

        coVerify { repository.analyzeHair(bitmap) }
    }

    @Test
    fun `extractMask delegates to repository segmentHair`() = runTest {
        val bitmap = mockk<Bitmap>()

        useCase.extractMask(bitmap)

        coVerify { repository.segmentHair(bitmap) }
    }

    @Test
    fun `detectLandmarks delegates to repository detectFaceLandmarks`() = runTest {
        val bitmap = mockk<Bitmap>()

        useCase.detectLandmarks(bitmap)

        coVerify { repository.detectFaceLandmarks(bitmap) }
    }
}
