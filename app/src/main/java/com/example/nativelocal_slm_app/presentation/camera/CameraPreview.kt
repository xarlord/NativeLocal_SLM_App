package com.example.nativelocal_slm_app.presentation.camera

import android.Manifest
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.LifecycleOwner
import com.google.accompanist.permissions.ExperimentalPermissionsApi
import com.google.accompanist.permissions.isGranted
import com.google.accompanist.permissions.rememberPermissionState
import java.util.concurrent.Executors

/**
 * Camera preview composable with real-time analysis.
 * Handles camera permissions and lifecycle management.
 */
@OptIn(ExperimentalPermissionsApi::class)
@Composable
fun CameraPreview(
    viewModel: CameraViewModel,
    modifier: Modifier = Modifier,
    onAnalysisComplete: () -> Unit = {}
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current

    // Camera permission
    val cameraPermissionState = rememberPermissionState(Manifest.permission.CAMERA)

    // Request permission on first composition
    LaunchedEffect(Unit) {
        if (!cameraPermissionState.status.isGranted) {
            cameraPermissionState.launchPermissionRequest()
        }
    }

    if (cameraPermissionState.status.isGranted) {
        CameraPreviewContent(
            viewModel = viewModel,
            context = context,
            lifecycleOwner = lifecycleOwner,
            modifier = modifier,
            onAnalysisComplete = onAnalysisComplete
        )
    }
}

@Composable
private fun CameraPreviewContent(
    viewModel: CameraViewModel,
    context: android.content.Context,
    lifecycleOwner: LifecycleOwner,
    modifier: Modifier = Modifier,
    onAnalysisComplete: () -> Unit
) {
    val previewView = remember { PreviewView(context) }
    var hasStartedCamera by remember { mutableStateOf(false) }

    AndroidView(
        factory = { previewView },
        modifier = modifier.fillMaxSize(),
        update = { view ->
            if (!hasStartedCamera) {
                val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
                cameraProviderFuture.addListener({
                    val cameraProvider = cameraProviderFuture.get()

                    // Preview use case
                    val preview = Preview.Builder()
                        .build()
                        .also {
                            it.setSurfaceProvider(view.surfaceProvider)
                        }

                    // ImageAnalysis for real-time processing
                    val imageAnalysis = ImageAnalysis.Builder()
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .setTargetResolution(android.util.Size(640, 480))
                        .build()
                        .also {
                            it.setAnalyzer(Executors.newSingleThreadExecutor()) { imageProxy ->
                                viewModel.onCameraFrame(imageProxy)
                            }
                        }

                    // Front camera
                    val cameraSelector = CameraSelector.DEFAULT_FRONT_CAMERA

                    try {
                        cameraProvider.unbindAll()
                        cameraProvider.bindToLifecycle(
                            lifecycleOwner,
                            cameraSelector,
                            preview,
                            imageAnalysis
                        )
                        viewModel.startCamera()
                        hasStartedCamera = true
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }, context.mainExecutor)
            }
        }
    )
}
