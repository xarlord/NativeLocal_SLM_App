@echo off
REM Script to run instrumented UI and E2E tests on emulator

echo ====================================
echo NativeLocal SLM App - Run Tests
echo ====================================
echo.

echo [1/4] Checking emulator connection...
"C:\Users\plner\AppData\Local\Android\Sdk\platform-tools\adb.exe" devices | findstr "device" > nul
if errorlevel 1 (
    echo ERROR: No emulator or device connected!
    echo.
    echo Please start an emulator or connect a device first:
    echo   "C:\Users\plner\AppData\Local\Android\Sdk\emulator\emulator.exe" -avd Pixel_6_API_33
    pause
    exit /b 1
)

echo Device/emulator found!
echo.

echo [2/4] Building debug APK with test coverage...
echo Please CLOSE Android Studio if it's open, then press any key to continue...
pause > nul

call gradlew.bat --stop
call gradlew.bat assembleDebug assembleDebugAndroidTest --no-daemon

if errorlevel 1 (
    echo BUILD FAILED!
    echo Make sure Android Studio is closed and try again.
    pause
    exit /b 1
)

echo.
echo [3/4] Installing app and tests...
call gradlew.bat installDebug installDebugAndroidTest --no-daemon

if errorlevel 1 (
    echo INSTALL FAILED!
    pause
    exit /b 1
)

echo.
echo [4/4] Running instrumented tests...
echo This will test UI components and E2E scenarios on the emulator.
echo.
echo ====================================
call gradlew.bat connectedAndroidTest --no-daemon

echo.
echo ====================================
echo Tests complete!
echo.
echo Test results are available at:
echo   app\build\reports\androidTests\connected\index.html
echo.
echo To view coverage report:
echo   gradlew.bat jacocoAndroidTestReport
echo.

pause
