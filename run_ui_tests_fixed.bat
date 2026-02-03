@echo off
setlocal EnableDelayedExpansion
set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr
set PATH=%JAVA_HOME%\bin;%PATH%
set PROJECT_DIR=C:\Users\plner\AndroidStudioProjects\NativeLocal_SLM_App

echo Rebuilding app with VIBRATE permission...
cd /d "%PROJECT_DIR%"
call "%PROJECT_DIR%\gradlew.bat" :app:installDebug

echo.
echo Running UI tests...
call "%PROJECT_DIR%\gradlew.bat" :app:connectedDebugAndroidTest

echo.
echo ============================================================
echo Test Results:
echo   Report: %PROJECT_DIR%\app\build\reports\androidTests\connected\debug\index.html
echo ============================================================
echo.

pause
