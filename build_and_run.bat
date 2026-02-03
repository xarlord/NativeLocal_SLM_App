@echo off
REM Script to build and run the app on emulator
REM This script handles Windows file locks by waiting for resources to be released

echo ====================================
echo NativeLocal SLM App - Build and Run
echo ====================================
echo.

echo [1/5] Checking for emulator...
"C:\Users\plner\AppData\Local\Android\Sdk\platform-tools\adb.exe" devices | findstr "device" > nul
if errorlevel 1 (
    echo No emulator running. Starting Pixel 6 API 33 emulator...
    start "" "C:\Users\plner\AppData\Local\Android\Sdk\emulator\emulator.exe" -avd Pixel_6_API_33 -gpu host
    echo Waiting for emulator to boot (this may take 30-60 seconds)...
    timeout /t 45 /nobreak > nul
)

echo.
echo [2/5] Waiting for file locks to be released...
echo Please CLOSE Android Studio if it's open, then press any key to continue...
pause > nul

echo.
echo [3/5] Stopping Gradle daemons...
call gradlew.bat --stop

echo.
echo [4/5] Cleaning and building debug APK...
call gradlew.bat clean assembleDebug --no-daemon

if errorlevel 1 (
    echo.
    echo BUILD FAILED!
    echo.
    echo Troubleshooting:
    echo 1. Make sure Android Studio is completely closed
    echo 2. Check Task Manager for any java.exe processes and end them
    echo 3. Try restarting your computer
    pause
    exit /b 1
)

echo.
echo [5/5] Installing app on emulator...
call gradlew.bat installDebug --no-daemon

if errorlevel 1 (
    echo INSTALL FAILED!
    pause
    exit /b 1
)

echo.
echo ====================================
echo Launching app on emulator...
echo ====================================
"C:\Users\plner\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell am start -n com.example.nativelocal_slm_app/.MainActivity

echo.
echo App is now running on the emulator!
echo.
echo To run instrumented tests, run:
echo   gradlew.bat connectedAndroidTest
echo.
pause
