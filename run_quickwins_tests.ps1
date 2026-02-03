# Run Quick Wins Tests Script
# Tests for ui.theme, presentation.di, ui.animation, and MainActivity

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Running Quick Wins Tests" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# Set JAVA_HOME to use Android Studio's JBR
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"

# Change to project directory
Set-Location "C:\Users\plner\AndroidStudioProjects\NativeLocal_SLM_App"

# Test 1: UI Theme Tests
Write-Host "Running ui.theme unit tests..." -ForegroundColor Yellow
& ".\gradlew.bat" ":app:testDebugUnitTest" "--tests", "com.example.nativelocal_slm_app.ui.theme.*"
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ UI Theme tests passed" -ForegroundColor Green
} else {
    Write-Host "✗ UI Theme tests failed" -ForegroundColor Red
}
Write-Host ""

# Test 2: UI Animation Tests
Write-Host "Running ui.animation unit tests..." -ForegroundColor Yellow
& ".\gradlew.bat" ":app:testDebugUnitTest" "--tests", "com.example.nativelocal_slm_app.ui.animation.*"
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ UI Animation tests passed" -ForegroundColor Green
} else {
    Write-Host "✗ UI Animation tests failed" -ForegroundColor Red
}
Write-Host ""

# Test 3: Presentation DI Tests
Write-Host "Running presentation.di unit tests..." -ForegroundColor Yellow
& ".\gradlew.bat" ":app:testDebugUnitTest" "--tests", "com.example.nativelocal_slm_app.presentation.di.*"
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Presentation DI tests passed" -ForegroundColor Green
} else {
    Write-Host "✗ Presentation DI tests failed" -ForegroundColor Red
}
Write-Host ""

# Test 4: MainActivity Instrumented Tests (requires emulator)
Write-Host "Running MainActivity instrumented tests (requires emulator)..." -ForegroundColor Yellow
Write-Host "Note: These tests require an emulator or device to be running" -ForegroundColor Gray
& ".\gradlew.bat" ":app:connectedDebugAndroidTest" "--tests", "com.example.nativelocal_slm_app.MainActivityTest"
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ MainActivity tests passed" -ForegroundColor Green
} else {
    Write-Host "✗ MainActivity tests failed or no device connected" -ForegroundColor Red
}
Write-Host ""

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Quick Wins Tests Complete" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
