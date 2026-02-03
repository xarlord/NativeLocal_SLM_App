@echo off
setlocal enabledelayedexpansion

set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr
set PATH=%JAVA_HOME%\bin;%PATH%

cd /d "C:\Users\plner\AndroidStudioProjects\NativeLocal_SLM_App"

echo Running UI Theme tests...
gradlew.bat :app:testDebugUnitTest --tests "com.example.nativelocal_slm_app.ui.theme.*"

echo.
echo Running UI Animation tests...
gradlew.bat :app:testDebugUnitTest --tests "com.example.nativelocal_slm_app.ui.animation.*"

echo.
echo Running Presentation DI tests...
gradlew.bat :app:testDebugUnitTest --tests "com.example.nativelocal_slm_app.presentation.di.*"
