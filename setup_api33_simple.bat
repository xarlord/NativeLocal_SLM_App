@echo off
setlocal EnableDelayedExpansion
set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr
set PATH=%JAVA_HOME%\bin;%PATH%
set SDK_DIR=C:\Users\plner\AppData\Local\Android\Sdk
set PROJECT_DIR=C:\Users\plner\AndroidStudioProjects\NativeLocal_SLM_App

echo ============================================================
echo API 33 Emulator Setup
echo ============================================================
echo.

echo [1/4] Checking prerequisites...
if exist "%SDK_DIR%\cmdline-tools\latest\bin\sdkmanager.bat" (
    echo [✓] Command-line tools installed
) else (
    echo ERROR: Command-line tools not found
    exit /b 1
)

if exist "%SDK_DIR%\system-images\android-33" (
    echo [✓] API 33 system image installed
) else (
    echo ERROR: API 33 system image not found
    exit /b 1
)

echo.
echo [2/4] Creating API 33 AVD...
"%SDK_DIR%\cmdline-tools\latest\bin\avdmanager.bat" create avd -n "Medium_Phone_API_33" -k "system-images;android-33;google_apis;x86_64" -d "medium" -f
echo [✓] AVD created
echo.

echo [3/4] Launching emulator...
start "" "%SDK_DIR%\emulator\emulator.exe" -avd Medium_Phone_API_33 -gpu host
echo Waiting for emulator to boot (90 seconds)...

REM Wait for boot
powershell -Command "Start-Sleep -s 90"

echo [✓] Emulator should be ready
echo.

echo [4/4] Running UI tests...
cd /d "%PROJECT_DIR%"
call "%PROJECT_DIR%\gradlew.bat" :app:connectedDebugAndroidTest

echo.
echo ============================================================
echo Setup Complete!
echo ============================================================
echo.
pause
