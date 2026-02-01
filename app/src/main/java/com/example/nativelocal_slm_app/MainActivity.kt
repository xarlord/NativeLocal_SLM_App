package com.example.nativelocal_slm_app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.example.nativelocal_slm_app.presentation.camera.CameraScreen
import com.example.nativelocal_slm_app.presentation.camera.CameraViewModel
import com.example.nativelocal_slm_app.presentation.camera.CapturedPhoto
import com.example.nativelocal_slm_app.presentation.onboarding.OnboardingScreen
import com.example.nativelocal_slm_app.presentation.onboarding.OnboardingViewModel
import com.example.nativelocal_slm_app.presentation.results.ResultsScreen
import com.example.nativelocal_slm_app.ui.theme.NativeLocal_SLM_AppTheme
import org.koin.android.ext.koin.androidContext
import org.koin.android.ext.koin.androidLogger
import org.koin.androidx.compose.koinViewModel
import org.koin.core.context.startKoin
import org.koin.core.logger.Level

/**
 * Main activity with navigation between screens.
 */
class MainActivity : ComponentActivity() {

    private var isKoinStarted = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize Koin only once
        if (!isKoinStarted) {
            startKoin {
                androidLogger(Level.ERROR)
                androidContext(this@MainActivity)
                modules(com.example.nativelocal_slm_app.presentation.di.appModule)
            }
            isKoinStarted = true
        }

        enableEdgeToEdge()
        setContent {
            NativeLocal_SLM_AppTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    AppNavigation()
                }
            }
        }
    }
}

@Composable
fun AppNavigation() {
    val navController = rememberNavController()
    val context = LocalContext.current
    val onboardingViewModel: OnboardingViewModel = viewModel()

    // Check if onboarding is complete
    var hasCompletedOnboarding by rememberSaveable { mutableStateOf(false) }
    var startDestination by remember { mutableStateOf("onboarding") }

    LaunchedEffect(Unit) {
        // In a real app, check SharedPreferences
        // For now, we'll just set it
        startDestination = "onboarding"
    }

    NavHost(
        navController = navController,
        startDestination = startDestination
    ) {
        // Onboarding Screen
        composable("onboarding") {
            OnboardingScreen(
                onComplete = {
                    hasCompletedOnboarding = true
                    navController.navigate("camera") {
                        popUpTo("onboarding") { inclusive = true }
                    }
                }
            )
        }

        // Camera Screen
        composable("camera") {
            val cameraViewModel: CameraViewModel = koinViewModel()

            CameraScreen(
                viewModel = cameraViewModel,
                onFilterClick = { /* Handled internally */ },
                onPhotoCaptured = { photo ->
                    // Navigate to results with the photo
                    // We'll serialize the photo data
                    navController.navigate("results")
                }
            )
        }

        // Results Screen
        composable("results") {
            // Get the cameraViewModel to access captured photo
            // In a real app, pass photo data via navigation arguments
            ResultsScreen(
                capturedPhoto = remember {
                    // Placeholder - will be populated by camera
                    CapturedPhoto(
                        originalImage = android.graphics.Bitmap.createBitmap(100, 100, android.graphics.Bitmap.Config.ARGB_8888),
                        processedImage = android.graphics.Bitmap.createBitmap(100, 100, android.graphics.Bitmap.Config.ARGB_8888),
                        appliedFilter = null,
                        analysisResult = null
                    )
                },
                onSave = {
                    navController.popBackStack("camera", inclusive = false)
                },
                onBack = {
                    navController.popBackStack()
                }
            )
        }
    }
}
