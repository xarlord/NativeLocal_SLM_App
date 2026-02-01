plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    jacoco
}

android {
    namespace = "com.example.nativelocal_slm_app"
    compileSdk {
        version = release(36)
    }

    defaultConfig {
        applicationId = "com.example.nativelocal_slm_app"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            isDebuggable = true
            applicationIdSuffix = ".debug"
            enableUnitTestCoverage = true
            enableAndroidTestCoverage = true
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }

    packagingOptions {
        resources.excludes.add("/META-INF/{AL2.0,LGPL2.1}")
        resources.excludes.add("META-INF/LICENSE*")
        resources.excludes.add("META-INF/NOTICE*")
        resources.excludes.add("META-INF/*.kotlin_module")
        resources.excludes.add("META-INF/INDEX.LIST")
        resources.pickFirsts.add("META-INF/LICENSE*")
        resources.pickFirsts.add("META-INF/NOTICE*")
    }

    testCoverage {
        jacocoVersion = "0.8.11"
    }
}

// Configure JaCoCo for code coverage
tasks.withType<JacocoReport> {
    dependsOn(tasks.withType<Test>())

    reports {
        xml.required.set(true)
        html.required.set(true)
        csv.required.set(false)
    }
}

// Add Jacoco test report task for unit tests
tasks.register<JacocoReport>("jacocoTestReport") {
    dependsOn("testDebugUnitTest")

    sourceDirectories.setFrom(files("${project.projectDir}/src/main/java"))
    classDirectories.setFrom(files("${project.buildDir}/intermediates/built_in_kotlinc/debug/compileDebugKotlin/classes"))
    executionData.setFrom(files("${project.buildDir}/jacoco/testDebugUnitTest.exec"))

    reports {
        xml.required.set(true)
        html.required.set(true)
    }
}

// Add Jacoco report task for instrumented tests
tasks.register<JacocoReport>("jacocoAndroidTestReport") {
    dependsOn("connectedDebugAndroidTest")

    sourceDirectories.setFrom(files("${project.projectDir}/src/main/java"))
    classDirectories.setFrom(
        files("${project.buildDir}/intermediates/built_in_kotlinc/debug/compileDebugKotlin/classes") +
        files("${project.buildDir}/intermediates/javac/debug/compileDebugJavaWithJavac/classes")
    )
    executionData.setFrom(fileTree("${project.buildDir}/outputs/code_coverage/debugAndroidTest/connected") {
        include("**/*.ec")
    })

    reports {
        xml.required.set(true)
        html.required.set(true)
    }
}

// Add merged coverage report task (unit + instrumented)
tasks.register<JacocoReport>("jacocoMergedReport") {
    dependsOn("testDebugUnitTest", "connectedDebugAndroidTest")

    sourceDirectories.setFrom(files("${project.projectDir}/src/main/java"))
    classDirectories.setFrom(
        files("${project.buildDir}/intermediates/built_in_kotlinc/debug/compileDebugKotlin/classes") +
        files("${project.buildDir}/intermediates/javac/debug/compileDebugJavaWithJavac/classes")
    )
    executionData.setFrom(
        files("${project.buildDir}/jacoco/testDebugUnitTest.exec") +
        fileTree("${project.buildDir}/outputs/code_coverage/debugAndroidTest/connected") {
            include("**/*.ec")
        }
    )

    reports {
        xml.required.set(true)
        html.required.set(true)
        csv.required.set(false)
    }
}

// Add coverage verification
tasks.register<JacocoCoverageVerification>("jacocoTestCoverageVerification") {
    dependsOn("jacocoTestReport")

    sourceDirectories.setFrom(files("${project.projectDir}/src/main/java"))
    classDirectories.setFrom(files("${project.buildDir}/intermediates/built_in_kotlinc/debug/compileDebugKotlin/classes"))
    executionData.setFrom(files("${project.buildDir}/jacoco/testDebugUnitTest.exec"))

    violationRules {
        rule {
            limit {
                minimum = "1.0".toBigDecimal() // 100% coverage required
            }
        }
    }
}

// Make build depend on coverage verification
tasks.named("check") {
    dependsOn("jacocoTestCoverageVerification")
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.material.icons.extended)

    // CameraX
    implementation(libs.androidx.camera.core)
    implementation(libs.androidx.camera.camera2)
    implementation(libs.androidx.camera.lifecycle)
    implementation(libs.androidx.camera.view)

    // MediaPipe
    implementation(libs.mediapipe.tasks.vision)

    // Coil for image loading
    implementation(libs.coil.compose)

    // Koin for dependency injection
    implementation(libs.koin.android)
    implementation(libs.koin.androidx.compose)

    // Kotlin Coroutines
    implementation(libs.kotlinx.coroutines.android)

    // Accompanist for permissions
    implementation(libs.accompanist.permissions)

    // Navigation Compose
    implementation(libs.androidx.navigation.compose)

    // Testing
    testImplementation(libs.junit)
    testImplementation(libs.kotlin.test)
    testImplementation(libs.robolectric)
    testImplementation(libs.mockk)
    testImplementation(libs.kotlinx.coroutines.test)
    testImplementation(libs.turbine)
    testImplementation(libs.koin.test)
    testImplementation(libs.koin.test.junit4)

    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    androidTestImplementation(libs.androidx.compose.ui.test.manifest)
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test:runner:1.5.2")
    androidTestImplementation("androidx.test:rules:1.5.0")
    androidTestImplementation("androidx.test.uiautomator:uiautomator:2.3.0")
    androidTestImplementation(libs.mockk)
    androidTestImplementation(libs.kotlinx.coroutines.test)

    debugImplementation(libs.androidx.compose.ui.tooling)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
}