@echo off
setlocal
set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
set "PATH=%JAVA_HOME%\bin;%PATH%"

cd /d "C:\Users\plner\AndroidStudioProjects\NativeLocal_SLM_App"

echo Installing app on API 33 emulator...
call gradlew.bat :app:installDebug

echo.
echo Running UI tests...
call gradlew.bat :app:connectedDebugAndroidTest

echo.
echo Done! Check results at:
echo app\build\reports\androidTests\connected\debug\index.html
echo.
