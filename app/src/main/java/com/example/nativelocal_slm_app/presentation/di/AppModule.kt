package com.example.nativelocal_slm_app.presentation.di

import com.example.nativelocal_slm_app.data.repository.FilterAssetsRepository
import com.example.nativelocal_slm_app.data.repository.MediaPipeHairRepository
import com.example.nativelocal_slm_app.domain.repository.HairAnalysisRepository
import com.example.nativelocal_slm_app.domain.repository.FilterRepository
import com.example.nativelocal_slm_app.domain.usecase.AnalyzeHairUseCase
import com.example.nativelocal_slm_app.domain.usecase.ApplyFilterUseCase
import com.example.nativelocal_slm_app.domain.usecase.ProcessCameraFrameUseCase
import com.example.nativelocal_slm_app.domain.usecase.SaveLookUseCase
import org.koin.android.ext.koin.androidContext
import org.koin.dsl.module

/**
 * Koin Dependency Injection module for the app.
 * Provides all dependencies for the hair analysis and filter application.
 */
val appModule = module {

    // Repositories
    single<HairAnalysisRepository> {
        MediaPipeHairRepository(androidContext())
    }

    single<FilterRepository> {
        FilterAssetsRepository(androidContext())
    }

    // Use Cases
    single {
        ProcessCameraFrameUseCase(get())
    }

    single {
        AnalyzeHairUseCase(get())
    }

    single {
        ApplyFilterUseCase(get(), get())
    }

    single {
        SaveLookUseCase(androidContext())
    }
}
