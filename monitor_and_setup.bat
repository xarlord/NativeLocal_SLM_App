@echo off
REM ============================================================
REM Monitor for Prerequisites and Auto-Setup API 33 Emulator
REM ============================================================

setlocal EnableDelayedExpansion

set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr
set PATH=%JAVA_HOME%\bin;%PATH%
set SDK_DIR=C:\Users\plner\AppData\Local\Android\Sdk
set PROJECT_DIR=C:\Users\plner\AndroidStudioProjects\NativeLocal_SLM_App

cls
echo ============================================================
echo API 33 Emulator Setup - Auto-Detect and Install
echo ============================================================
echo.
echo This script will monitor for required components and
echo automatically proceed when they're installed.
echo.

REM Check prerequisites
set TOOLS_INSTALLED=0
set API33_INSTALLED=0

:check_loop
cls
echo ============================================================
echo Checking Prerequisites...
echo ============================================================
echo.

REM Check command-line tools
if exist "%SDK_DIR%\cmdline-tools\latest\bin\sdkmanager.bat" (
    echo [✓] Android SDK Command-line Tools installed
    set TOOLS_INSTALLED=1
) else (
    echo [ ] Android SDK Command-line Tools NOT installed
    echo     Please install in Android Studio:
    echo     Tools -^> SDK Manager -^> SDK Tools -^> Check "Command-line Tools"
    set TOOLS_INSTALLED=0
)
echo.

REM Check API 33 system image
if exist "%SDK_DIR%\system-images\android-33" (
    echo [✓] API 33 System Image installed
    set API33_INSTALLED=1
) else (
    echo [ ] API 33 System Image NOT installed
    echo     Please install in Android Studio:
    echo     Tools -^> SDK Manager -^> SDK Platforms -^> Check "Android 13.0 (API 33)"
    echo     Then download "Google APIs Intel x86_64 Atom System Image"
    set API33_INSTALLED=0
)
echo.

REM If both installed, proceed
if %TOOLS_INSTALLED% equ 1 (
    if %API33_INSTALLED% equ 1 (
        goto :all_ready
    )
)

echo ============================================================
echo Waiting for prerequisites to be installed...
echo ============================================================
echo.
echo Android Studio should already be open.
echo Please follow the instructions above, then this script
echo will automatically detect and continue.
echo.
echo Checking again in 10 seconds...
echo.

timeout /t 10 /nobreak >nul
goto :check_loop

:all_ready
cls
echo ============================================================
echo All Prerequisites Ready! Starting Setup...
echo ============================================================
echo.

REM Check if AVD exists
"%SDK_DIR%\emulator\emulator.exe" -list-avds 2>nul | findstr /i "api.33\|api_33" >nul
if %errorlevel% equ 0 (
    echo [1/3] API 33 AVD already exists, skipping creation...
    set AVD_NAME=Medium_Phone_API_33
    for /f %%i in ('"%SDK_DIR%\emulator\emulator.exe" -list-avds ^| findstr /i "api.33\|api_33"') do set AVD_NAME=%%i
) else (
    echo [1/3] Creating API 33 AVD...
    "%SDK_DIR%\cmdline-tools\latest\bin\avdmanager.bat" create avd -n "Medium_Phone_API_33" -k "system-images;android-33;google_apis;x86_64" -d "medium" -f
    if %errorlevel% neq 0 (
        echo ERROR: Failed to create AVD
        pause
        exit /b 1
    )
    set AVD_NAME=Medium_Phone_API_33
)

echo [1/3] AVD ready: %AVD_NAME%
echo.

echo [2/3] Launching API 33 Emulator...
echo.
start "" "%SDK_DIR%\emulator\emulator.exe" -avd %AVD_NAME% -gpu host -no-snapshot-load

echo Waiting for emulator to boot (this may take 30-60 seconds)...
timeout /t 30 /nobreak >nul

REM Wait for boot completion
echo Waiting for Android system to fully boot...
timeout /t 60 /nobreak >nul

echo Checking emulator status...
"%SDK_DIR%\platform-tools\adb.exe" devices | findstr /i "emulator" >nul
if %errorlevel% neq 0 (
    echo WARNING: Emulator not responding yet
    echo Waiting 30 more seconds...
    timeout /t 30 /nobreak >nul
)

echo [2/3] Emulator running ✓
echo.

echo [3/3] Running UI Tests...
echo.
cd /d "%PROJECT_DIR%"

echo ============================================================
echo Executing: gradlew.bat :app:connectedDebugAndroidTest
echo ============================================================
echo.

call "%PROJECT_DIR%\gradlew.bat" :app:connectedDebugAndroidTest

if %errorlevel% equ 0 (
    echo.
    echo ============================================================
    echo SUCCESS! All tests passed!
    echo ============================================================
    echo.
) else (
    echo.
    echo ============================================================
    echo Some tests failed. Check the report at:
    echo %PROJECT_DIR%\app\build\reports\androidTests\connected\debug\index.html
    echo ============================================================
    echo.
)

echo.
echo Test Results:
echo   Report: %PROJECT_DIR%\app\build\reports\androidTests\connected\debug\index.html
echo.
echo Coverage Report:
echo   Run: gradlew.bat jacocoAndroidTestReport
echo   Location: %PROJECT_DIR%\app\build\reports\jacoco\jacocoAndroidTestReport\html\index.html
echo.

pause
