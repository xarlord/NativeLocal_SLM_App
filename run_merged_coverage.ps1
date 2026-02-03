$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"

Set-Location "C:\Users\plner\AndroidStudioProjects\NativeLocal_SLM_App"

Write-Host "Generating merged coverage report (unit + instrumented tests)..."
& ".\gradlew.bat" ":app:jacocoMergedReport"

Write-Host ""
Write-Host "Merged coverage report generated at:"
Write-Host "app/build/reports/jacoco/jacocoMergedReport/html/index.html"
