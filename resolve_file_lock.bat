@echo off
REM Script to resolve Windows file lock issues with Gradle build directory
REM Usage: Close Android Studio, then run this script as Administrator

echo ========================================
echo File Lock Resolution Script
echo ========================================
echo.

echo Step 1: Stopping all Gradle daemons...
call gradlew.bat --stop
timeout /t 3 /nobreak > nul

echo.
echo Step 2: Checking for Java processes...
tasklist /FI "IMAGENAME eq java.exe" 2>nul | find /I "java.exe" > nul
if %ERRORLEVEL% equ 0 (
    echo WARNING: Java processes are still running!
    echo.
    echo Attempting to terminate Java processes...
    taskkill /F /IM java.exe > nul 2>&1
    timeout /t 2 /nobreak > nul
) else (
    echo No Java processes found.
)

echo.
echo Step 3: Checking for Gradle processes...
tasklist /FI "IMAGENAME eq gradle*" 2>nul | find /I "gradle" > nul
if %ERRORLEVEL% equ 0 (
    echo WARNING: Gradle processes are still running!
    echo.
    echo Attempting to terminate Gradle processes...
    taskkill /F /IM gradle.exe > nul 2>&1
    timeout /t 2 /nobreak > nul
) else (
    echo No Gradle processes found.
)

echo.
echo Step 4: Attempting to delete build directory...
if exist "app\build" (
    echo Build directory exists, attempting to remove...
    rd /s /q "app\build" 2>nul
    timeout /t 2 /nobreak > nul

    if exist "app\build" (
        echo.
        echo ========================================
        echo FAILED: Build directory is still locked!
        echo ========================================
        echo.
        echo Please follow these manual steps:
        echo 1. Close ALL instances of Android Studio
        echo 2. Close any terminal windows running Gradle
        echo 3. Restart your computer
        echo 4. Run: gradlew.bat clean
        echo 5. Run: gradlew.bat :app:testDebugUnitTest
        echo.
        pause
        exit /b 1
    ) else (
        echo SUCCESS: Build directory removed!
    )
) else (
    echo Build directory does not exist.
)

echo.
echo ========================================
echo Step 5: Running tests...
echo ========================================
echo.
call gradlew.bat :app:testDebugUnitTest --console=plain

echo.
echo ========================================
echo Script complete!
echo ========================================
pause
