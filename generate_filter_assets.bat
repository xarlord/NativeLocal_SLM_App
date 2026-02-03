@echo off
REM Generate simple PNG filter assets for testing
REM This creates basic colored overlays using ImageMagick or manual creation

echo ========================================
echo Filter Asset Generator
echo ========================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Python not found. Please install Python from https://python.org
    echo.
    echo Alternative: Manually add PNG images to:
    echo   app\src\main\assets\filters\face\batman\mask.png
    echo   app\src\main\assets\filters\face\batman\eyes.png
    echo   app\src\main\assets\filters\face\joker\mask.png
    echo   app\src\main\assets\filters\face\joker\eyes.png
    echo   app\src\main\assets\filters\hair\fire_hair\hair_overlay.png
    echo   app\src\main\assets\filters\hair\neon_glow\hair_overlay.png
    echo   app\src\main\assets\filters\hair\punk_mohawk\hair_overlay.png
    pause
    exit /b 1
)

echo Found Python. Generating filter assets...
echo.

REM Install Pillow if needed
echo Checking for Pillow library...
python -c "import PIL" 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo Installing Pillow...
    pip install Pillow
)

echo.
echo Generating PNG images...
python generate_filter_assets.py

echo.
echo ========================================
echo Done! Filter assets created.
echo ========================================
echo.
pause
