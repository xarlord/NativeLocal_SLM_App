$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"

Set-Location "C:\Users\plner\AndroidStudioProjects\NativeLocal_SLM_App"

Write-Host "Uninstalling old version..."
& "./gradlew.bat" ":app:uninstallDebug"

Write-Host "Installing new version..."
& "./gradlew.bat" ":app:installDebug"

Write-Host "Running tests..."
& "./gradlew.bat" ":app:connectedDebugAndroidTest"
