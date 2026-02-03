$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"

Set-Location "C:\Users\plner\AndroidStudioProjects\NativeLocal_SLM_App"

Write-Host "Running CameraViewModel unit tests..."
& ".\gradlew.bat" ":app:testDebugUnitTest" "--tests", "com.example.nativelocal_slm_app.presentation.camera.CameraViewModelTest"
