# Windows File Lock Issue - Resolution Guide

## Problem

Gradle cannot delete or write to the build directory due to file locks:
```
java.nio.file.AccessDeniedException: app\build\generated\source\buildConfig\debug
```

## Root Cause

This is a common Windows issue caused by:
1. **Android Studio** holding file locks on build artifacts
2. **Background Gradle daemons** still running
3. **Windows Defender** or antivirus scanning files
4. **Other processes** (emulator, ADB) holding locks

## Automated Resolution

### Option 1: Run the Resolution Script

1. **Close Android Studio completely** (File → Exit)
2. **Open Command Prompt as Administrator**
3. Navigate to project directory:
   ```cmd
   cd C:\Users\plner\AndroidStudioProjects\NativeLocal_SLM_App
   ```
4. Run the resolution script:
   ```cmd
   resolve_file_lock.bat
   ```

The script will:
- Stop all Gradle daemons
- Kill any Java/Gradle processes
- Attempt to delete the build directory
- Run the tests automatically

### Option 2: Manual Resolution

If the script doesn't work, follow these steps:

#### Step 1: Close All Applications
1. Close **Android Studio** completely (not just the window)
2. Close all **command prompt/terminal** windows
3. Close **emulator** instances

#### Step 2: Restart Your Computer
This is the most reliable way to clear all file locks on Windows.

#### Step 3: Clean and Build
After restart, open a new command prompt:
```cmd
cd C:\Users\plner\AndroidStudioProjects\NativeLocal_SLM_App
gradlew.bat --stop
gradlew.bat clean
gradlew.bat :app:testDebugUnitTest
```

## Why This Happens

Windows has strict file locking mechanisms. When a process (like Android Studio's build system) opens a file, other processes cannot modify or delete it until:
- The process closes the file
- The process terminates
- The system is restarted

## Workaround (If You Can't Restart)

If you cannot restart immediately, you can still work on the project:

### Option A: Use Android Studio's Built-in Test Runner
1. Open the project in Android Studio
2. Right-click on `FilterAssetsRepositoryTest.kt`
3. Select "Run 'FilterAssetsRepositoryTest'"
4. Android Studio manages locks better than command-line Gradle

### Option B: Use Git to See What Changed
The changes have been committed (commit 33709ea), so you won't lose any work:
```cmd
git log --oneline -1
git show 33709ea --stat
```

### Option C: Review the Changes Locally
```cmd
git diff HEAD~1 HEAD
```

## Verification

After resolving the lock, verify everything works:

```cmd
# Should show 415+ tests passing
gradlew.bat :app:testDebugUnitTest

# Should show improved coverage
gradlew.bat :app:jacocoTestReport

# Open the coverage report
start app\build\reports\jacoco\jacocoTestReport\html\index.html
```

## Expected Results

After successful test execution:
- **Total tests**: 415+ (up from 408)
- **FilterAssetsRepository**: 14 tests passing
- **OnboardingViewModel**: 15 tests passing
- **Coverage improvements**:
  - data.repository: 0% → 60-80%
  - presentation.onboarding: 9% → 80-90%

## Prevention

To avoid this issue in the future:

1. **Close Android Studio before running Gradle commands** from terminal
2. **Use `--no-daemon` flag** to prevent background daemons:
   ```cmd
   gradlew.bat :app:testDebugUnitTest --no-daemon
   ```
3. **Regularly stop daemons**:
   ```cmd
   gradlew.bat --stop
   ```
4. **Keep Windows Defender excluded** from project directory:
   - Add `C:\Users\plner\AndroidStudioProjects\NativeLocal_SLM_App` to Windows Defender exclusions

## Contact

If the issue persists after following these steps:
1. Check Windows Event Viewer for disk/file system errors
2. Run `chkdsk /f` on your drive
3. Temporarily disable antivirus software

---

**Last Updated**: 2026-02-01
**Issue**: Windows file locks preventing Gradle build
**Status**: Requires manual intervention (close apps/restart)
