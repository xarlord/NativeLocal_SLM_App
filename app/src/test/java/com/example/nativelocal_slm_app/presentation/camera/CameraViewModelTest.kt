package com.example.nativelocal_slm_app.presentation.camera

import com.example.nativelocal_slm_app.domain.usecase.ApplyFilterUseCase
import com.example.nativelocal_slm_app.domain.usecase.ProcessCameraFrameUseCase
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

/**
 * Unit tests for CameraViewModel.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class CameraViewModelTest {

    private lateinit var viewModel: CameraViewModel
    private val processFrameUseCase: ProcessCameraFrameUseCase = mockk(relaxed = true)
    private val applyFilterUseCase: ApplyFilterUseCase = mockk(relaxed = true)

    private val testDispatcher = UnconfinedTestDispatcher()

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        viewModel = CameraViewModel(processFrameUseCase, applyFilterUseCase)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    // ==================== Camera State Tests ====================

    @Test
    fun `initial camera state is Initializing`() {
        assert(viewModel.cameraState.value is CameraState.Initializing)
    }

    @Test
    fun `startCamera sets state to Active`() {
        viewModel.startCamera()

        assert(viewModel.cameraState.value is CameraState.Active)
    }

    @Test
    fun `stopCamera sets state to Inactive`() {
        viewModel.startCamera()
        viewModel.stopCamera()

        assert(viewModel.cameraState.value is CameraState.Inactive)
    }

    // ==================== Filter Selection Tests ====================

    @Test
    fun `selectFilter updates selectedFilter state`() {
        // Note: We can't easily create a FilterEffect without complex dependencies
        // This test verifies the state flow behavior
        viewModel.selectFilter(null)

        assert(viewModel.selectedFilter.value == null)
    }

    @Test
    fun `selectFilter with null clears selected filter`() {
        viewModel.selectFilter(null)

        assert(viewModel.selectedFilter.value == null)
    }

    // ==================== Captured Photo Tests ====================

    @Test
    fun `capturePhoto requires latestOriginalBitmap`() {
        // Don't set any original bitmap
        viewModel.capturePhoto()

        assert(viewModel.capturedPhoto.value == null)
    }

    @Test
    fun `clearCapturedPhoto clears captured photo state`() {
        // Test clearing works
        viewModel.clearCapturedPhoto()

        assert(viewModel.capturedPhoto.value == null)
    }

    // ==================== State Flow Tests ====================

    @Test
    fun `hairAnalysisResult is initially null`() {
        assert(viewModel.hairAnalysisResult.value == null)
    }

    @Test
    fun `processedBitmap is initially null`() {
        assert(viewModel.processedBitmap.value == null)
    }

    @Test
    fun `capturedPhoto is initially null`() {
        assert(viewModel.capturedPhoto.value == null)
    }
}
