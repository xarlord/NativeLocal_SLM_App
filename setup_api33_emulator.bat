@echo off
REM ============================================================
REM Automated API 33 Emulator Setup for NativeLocal_SLM_App
REM ============================================================

setlocal EnableDelayedExpansion

set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr
set PATH=%JAVA_HOME%\bin;%PATH%
set SDK_DIR=C:\Users\plner\AppData\Local\Android\Sdk
set PROJECT_DIR=C:\Users\plner\AndroidStudioProjects\NativeLocal_SLM_App

echo ============================================================
echo API 33 Emulator Setup Script
echo ============================================================
echo.

REM Check if command-line tools are installed
if not exist "%SDK_DIR%\cmdline-tools\latest\bin\sdkmanager.bat" (
    echo ERROR: Android SDK Command-line Tools not installed!
    echo.
    echo Please follow these steps:
    echo 1. Open Android Studio
    echo 2. Go to Tools -^> SDK Manager
    echo 3. Click "SDK Tools" tab
    echo 4. Check "Android SDK Command-line Tools (latest)"
    echo 5. Click Apply to install
    echo 6. Run this script again
    echo.
    echo Opening Android Studio for you...
    start "" "C:\Program Files\Android\Android Studio\bin\studio.bat"
    pause
    exit /b 1
)

echo [1/5] Command-line tools found ✓
echo.

REM Check if API 33 system image is downloaded
if not exist "%SDK_DIR%\system-images\android-33" (
    echo [2/5] API 33 System Image not found...
    echo.
    echo Opening Android Studio SDK Manager...
    echo Please download Android 13.0 (API 33) system image:
    echo   - Check "Android 13.0 (API 33)"
    echo   - Check "Google APIs Intel x86_64 Atom System Image"
    echo   - Click Apply
    echo.
    start "" "C:\Program Files\Android\Android Studio\bin\studio.bat"
    echo.
    echo After downloading, run this script again.
    pause
    exit /b 1
)

echo [2/5] API 33 System Image found ✓
echo.

REM Check if AVD already exists
"%SDK_DIR%\emulator\emulator.exe" -list-avds | findstr /i "api_33" >nul
if %errorlevel% equ 0 (
    echo [3/5] API 33 AVD already exists ✓
    set AVD_NAME=Medium_Phone_API_33
) else (
    echo [3/5] Creating API 33 AVD...
    echo.
    "%SDK_DIR%\cmdline-tools\latest\bin\avdmanager.bat" create avd -n "Medium_Phone_API_33" -k "system-images;android-33;google_apis;x86_64" -d "medium" -f
    if %errorlevel% neq 0 (
        echo ERROR: Failed to create AVD
        pause
        exit /b 1
    )
    echo.
    echo [3/5] API 33 AVD created ✓
    set AVD_NAME=Medium_Phone_API_33
)

echo.
echo [4/5] Launching API 33 Emulator...
echo.
start "" "%SDK_DIR%\emulator\emulator.exe" -avd %AVD_NAME% -gpu host

echo Waiting for emulator to boot...
timeout /t 30 /nobreak >nul

REM Check if emulator is running
"%SDK_DIR%\platform-tools\adb.exe" devices | findstr /i "emulator" >nul
if %errorlevel% neq 0 (
    echo ERROR: Emulator not responding
    pause
    exit /b 1
)

echo [4/5] Emulator is running ✓
echo.

REM Wait for boot to complete
echo Waiting for Android to fully boot...
timeout /t 60 /nobreak >nul

echo.
echo [5/5] Running UI Tests...
echo.
cd /d "%PROJECT_DIR%"
call "%PROJECT_DIR%\gradlew.bat" :app:connectedDebugAndroidTest

echo.
echo ============================================================
echo Setup Complete!
echo ============================================================
echo.
echo Check test results at:
echo   %PROJECT_DIR%\app\build\reports\androidTests\connected\debug\index.html
echo.
echo Coverage report at:
echo   %PROJECT_DIR%\app\build\reports\jacoco\jacocoAndroidTestReport\html\index.html
echo.

pause
