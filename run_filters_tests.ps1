# Run Presentation Filters Tests Script
# Requires API 33 emulator or connected device

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Running Presentation Filters Tests" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# Set JAVA_HOME to use Android Studio's JBR
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"

# Change to project directory
Set-Location "C:\Users\plner\AndroidStudioProjects\NativeLocal_SLM_App"

# Check for connected device/emulator
Write-Host "Checking for connected devices..." -ForegroundColor Yellow
$devices = & adb devices | Select-String -Pattern "device$" | Where-Object { $_ -notmatch "emulator" }

if (-not $devices) {
    Write-Host "No device or emulator detected!" -ForegroundColor Red
    Write-Host "Please start an emulator (API 33 recommended) or connect a device." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To start emulator:" -ForegroundColor Gray
    Write-Host "  1. Open Android Studio" -ForegroundColor Gray
    Write-Host "  2. Tools -> Device Manager" -ForegroundColor Gray
    Write-Host "  3. Start your API 33 emulator" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

Write-Host "Device found! Running tests..." -ForegroundColor Green
Write-Host ""

# Test 1: FilterCarousel Tests
Write-Host "Running FilterCarousel tests..." -ForegroundColor Yellow
& ".\gradlew.bat" ":app:connectedDebugAndroidTest" "--tests", "com.example.nativelocal_slm_app.presentation.filters.FilterCarouselTest"
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ FilterCarousel tests passed" -ForegroundColor Green
} else {
    Write-Host "✗ FilterCarousel tests failed" -ForegroundColor Red
}
Write-Host ""

# Test 2: FilterSelectionSheet Tests
Write-Host "Running FilterSelectionSheet tests..." -ForegroundColor Yellow
& ".\gradlew.bat" ":app:connectedDebugAndroidTest" "--tests", "com.example.nativelocal_slm_app.presentation.filters.FilterSelectionSheetTest"
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ FilterSelectionSheet tests passed" -ForegroundColor Green
} else {
    Write-Host "✗ FilterSelectionSheet tests failed" -ForegroundColor Red
}
Write-Host ""

# Test 3: ColorPickerSheet Tests
Write-Host "Running ColorPickerSheet tests..." -ForegroundColor Yellow
& ".\gradlew.bat" ":app:connectedDebugAndroidTest" "--tests", "com.example.nativelocal_slm_app.presentation.filters.ColorPickerSheetTest"
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ ColorPickerSheet tests passed" -ForegroundColor Green
} else {
    Write-Host "✗ ColorPickerSheet tests failed" -ForegroundColor Red
}
Write-Host ""

# Test 4: StyleSelectionSheet Tests
Write-Host "Running StyleSelectionSheet tests..." -ForegroundColor Yellow
& ".\gradlew.bat" ":app:connectedDebugAndroidTest" "--tests", "com.example.nativelocal_slm_app.presentation.filters.StyleSelectionSheetTest"
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ StyleSelectionSheet tests passed" -ForegroundColor Green
} else {
    Write-Host "✗ StyleSelectionSheet tests failed" -ForegroundColor Red
}
Write-Host ""

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Presentation Filters Tests Complete" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
