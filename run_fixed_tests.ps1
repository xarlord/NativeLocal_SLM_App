$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"

Set-Location "C:\Users\plner\AndroidStudioProjects\NativeLocal_SLM_App"

Write-Host "Running UI tests with fixed OnboardingScreen test..."
& "./gradlew.bat" ":app:connectedDebugAndroidTest"
