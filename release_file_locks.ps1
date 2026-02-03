# PowerShell script to kill processes holding file locks
# Run this script if you get "AccessDeniedException" during build

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " NativeLocal SLM App - File Lock Release" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/4] Checking for Gradle processes..." -ForegroundColor Yellow
$gradleProcesses = Get-Process -Name "java*" -ErrorAction SilentlyContinue | Where-Object {
    $_.CommandLine -like "*gradle*" -or $_.CommandLine -like "*.gradlew*"
}

if ($gradleProcesses) {
    Write-Host "Found $($gradleProcesses.Count) Gradle process(es)" -ForegroundColor Red
    $gradleProcesses | ForEach-Object {
        Write-Host "  - PID: $($_.Id), Path: $($_.Path)" -ForegroundColor Gray
    }

    Write-Host ""
    $response = Read-Host "Kill Gradle processes? (Y/N)"
    if ($response -eq 'Y' -or $response -eq 'y') {
        $gradleProcesses | Stop-Process -Force
        Write-Host "Gradle processes killed" -ForegroundColor Green
    }
} else {
    Write-Host "No Gradle processes found" -ForegroundColor Green
}

Write-Host ""
Write-Host "[2/4] Checking for Java build processes..." -ForegroundColor Yellow
$javaProcesses = Get-Process -Name "java*" -ErrorAction SilentlyContinue | Where-Object {
    $_.CommandLine -like "*Android*" -or $_.CommandLine -like "*Kotlin*"
}

if ($javaProcesses) {
    Write-Host "Found $($javaProcesses.Count) Java build process(es)" -ForegroundColor Red
    $javaProcesses | ForEach-Object {
        Write-Host "  - PID: $($_.Id), Path: $($_.Path)" -ForegroundColor Gray
    }

    Write-Host ""
    $response = Read-Host "Kill Java build processes? (Y/N)"
    if ($response -eq 'Y' -or $response -eq 'y') {
        $javaProcesses | Stop-Process -Force
        Write-Host "Java processes killed" -ForegroundColor Green
    }
} else {
    Write-Host "No Java build processes found" -ForegroundColor Green
}

Write-Host ""
Write-Host "[3/4] Stopping Gradle daemons..." -ForegroundColor Yellow
Set-Location "C:\Users\plner\AndroidStudioProjects\NativeLocal_SLM_App"
& .\gradlew.bat --stop

Write-Host ""
Write-Host "[4/4] Waiting for file locks to release..." -ForegroundColor Yellow
Write-Host "Please CLOSE Android Studio now if it's open." -ForegroundColor Cyan
Write-Host ""
Start-Sleep -Seconds 5

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " File Lock Release Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "You can now run:" -ForegroundColor Cyan
Write-Host "  .\build_and_run.bat" -ForegroundColor White
Write-Host "  .\run_tests_on_emulator.bat" -ForegroundColor White
Write-Host ""
Write-Host "Or manually:" -ForegroundColor Cyan
Write-Host "  gradlew.bat assembleDebug" -ForegroundColor White
Write-Host "  gradlew.bat installDebug" -ForegroundColor White
Write-Host "  gradlew.bat connectedAndroidTest" -ForegroundColor White
Write-Host ""

# Offer to immediately start build
$response = Read-Host "Start build and run now? (Y/N)"
if ($response -eq 'Y' -or $response -eq 'y') {
    Write-Host ""
    Write-Host "Starting build..." -ForegroundColor Yellow
    & .\build_and_run.bat
}
