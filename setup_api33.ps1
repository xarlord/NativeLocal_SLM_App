# PowerShell script to set up API 33 emulator and run tests

$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"

$SDK_DIR = "C:\Users\plner\AppData\Local\Android\Sdk"
$PROJECT_DIR = "C:\Users\plner\AndroidStudioProjects\NativeLocal_SLM_App"

Write-Host "============================================================"
Write-Host "API 33 Emulator Setup"
Write-Host "============================================================"
Write-Host ""

# Check prerequisites
Write-Host "[1/5] Checking prerequisites..."
if (Test-Path "$SDK_DIR\cmdline-tools\latest\bin\sdkmanager.bat") {
    Write-Host "[✓] Command-line tools found"
} else {
    Write-Host "[✗] Command-line tools NOT found"
    exit 1
}

if (Test-Path "$SDK_DIR\system-images\android-33") {
    Write-Host "[✓] API 33 system image found"
} else {
    Write-Host "[✗] API 33 system image NOT found"
    exit 1
}

Write-Host ""

# List available devices
Write-Host "[2/5] Listing available device definitions..."
& "$SDK_DIR\cmdline-tools\latest\bin\avdmanager.bat" list device
Write-Host ""

# Create AVD (using pixel_6 as the device)
Write-Host "[3/5] Creating API 33 AVD (Pixel 6)..."
& "$SDK_DIR\cmdline-tools\latest\bin\avdmanager.bat" create avd -n "Pixel_6_API_33" -k "system-images;android-33;google_apis;x86_64" -d "pixel_6" -f
Write-Host "[✓] AVD created"
Write-Host ""

# Launch emulator
Write-Host "[4/5] Launching emulator..."
Start-Process -FilePath "$SDK_DIR\emulator\emulator.exe" -ArgumentList "-avd", "Pixel_6_API_33", "-gpu", "host"
Write-Host "Waiting 90 seconds for emulator to boot..."
Start-Sleep -s 90
Write-Host "[✓] Emulator launched"
Write-Host ""

# Run tests
Write-Host "[5/5] Running UI tests..."
Set-Location $PROJECT_DIR
& "$PROJECT_DIR\gradlew.bat" ":app:connectedDebugAndroidTest"

Write-Host ""
Write-Host "============================================================"
Write-Host "Setup Complete!"
Write-Host "============================================================"
