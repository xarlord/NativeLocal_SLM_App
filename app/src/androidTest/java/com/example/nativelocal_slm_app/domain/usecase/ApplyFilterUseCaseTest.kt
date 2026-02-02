package com.example.nativelocal_slm_app.domain.usecase

import android.graphics.Bitmap
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.example.nativelocal_slm_app.data.model.FilterCategory
import com.example.nativelocal_slm_app.data.model.FilterEffect
import com.example.nativelocal_slm_app.data.repository.FilterAssetsRepository
import com.example.nativelocal_slm_app.domain.repository.HairAnalysisRepository
import io.mockk.coEvery
import io.mockk.coVerify
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
 * Instrumented tests for ApplyFilterUseCase.
 * These tests require real Android environment for Bitmap operations.
 */
@RunWith(AndroidJUnit4::class)
@OptIn(ExperimentalCoroutinesApi::class)
class ApplyFilterUseCaseTest {

    private lateinit var useCase: ApplyFilterUseCase
    private val filterAssetsRepository: FilterAssetsRepository = mockk(relaxed = true)
    private val hairAnalysisRepository: HairAnalysisRepository = mockk(relaxed = true)
    private val testDispatcher = UnconfinedTestDispatcher()

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        useCase = ApplyFilterUseCase(filterAssetsRepository, hairAnalysisRepository)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun invoke_loadsFilterAssets_forFaceFilter() = runTest {
        val originalBitmap = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)
        val filter = FilterEffect(
            id = "test_face_filter",
            name = "Test Face Filter",
            category = FilterCategory.FACE,
            thumbnailRes = "test.png"
        )

        coEvery { filterAssetsRepository.loadFilterAssets(filter.id) } returns mockk()

        val result = useCase(originalBitmap, filter, mockk())

        // Verify a bitmap is returned
        assert(result != null)
        assert(result.width == originalBitmap.width)
        assert(result.height == originalBitmap.height)

        coVerify { filterAssetsRepository.loadFilterAssets(filter.id) }
    }

    @Test
    fun invoke_loadsFilterAssets_forHairFilter() = runTest {
        val originalBitmap = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)
        val filter = FilterEffect(
            id = "test_hair_filter",
            name = "Test Hair Filter",
            category = FilterCategory.HAIR,
            thumbnailRes = "test.png"
        )

        coEvery { filterAssetsRepository.loadFilterAssets(filter.id) } returns mockk()

        val result = useCase(originalBitmap, filter, mockk())

        assert(result != null)
        coVerify { filterAssetsRepository.loadFilterAssets(filter.id) }
    }

    @Test
    fun invoke_loadsFilterAssets_forComboFilter() = runTest {
        val originalBitmap = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)
        val filter = FilterEffect(
            id = "test_combo_filter",
            name = "Test Combo Filter",
            category = FilterCategory.COMBO,
            thumbnailRes = "test.png"
        )

        coEvery { filterAssetsRepository.loadFilterAssets(filter.id) } returns mockk()

        val result = useCase(originalBitmap, filter, mockk())

        assert(result != null)
        coVerify { filterAssetsRepository.loadFilterAssets(filter.id) }
    }

    @Test
    fun invoke_handlesNullAssets_gracefully() = runTest {
        val originalBitmap = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)
        val filter = FilterEffect(
            id = "test_filter",
            name = "Test Filter",
            category = FilterCategory.FACE,
            thumbnailRes = "test.png"
        )

        coEvery { filterAssetsRepository.loadFilterAssets(filter.id) } returns null

        val result = useCase(originalBitmap, filter, mockk())

        // Should still return a bitmap (just unchanged)
        assert(result != null)
    }
}
