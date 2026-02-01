package com.example.nativelocal_slm_app

import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.ext.junit.runners.AndroidJUnit4

import org.junit.Test
import org.junit.runner.RunWith

import org.junit.Assert.*

/**
 * Instrumented test, which will execute on an Android device.
 *
 * See [testing documentation](http://d.android.com/tools/testing).
 */
@RunWith(AndroidJUnit4::class)
class ExampleInstrumentedTest {
    @Test
    fun useAppContext() {
        // Context of the app under test.
        val appContext = InstrumentationRegistry.getInstrumentation().targetContext
        // Handle both debug and release variants
        val expectedPackage = if (appContext.packageName.endsWith(".debug")) {
            "com.example.nativelocal_slm_app.debug"
        } else {
            "com.example.nativelocal_slm_app"
        }
        assertEquals(expectedPackage, appContext.packageName)
    }
}