# Quick Visual Guide: Setup API 33 Emulator (5 Steps)

## Step 1: Install SDK Command-Line Tools

### In Android Studio:
1. **Tools** → **SDK Manager**
2. Click **SDK Tools** tab
3. ✅ Check **Android SDK Command-line Tools (latest)**
4. Click **Apply**
5. Click **OK** to accept licenses
6. Wait for installation (1-2 minutes)
7. Click **Finish**

**Screenshot:**
```
┌─────────────────────────────────────────┐
│ SDK Manager                              │
├─────────────────────────────────────────┤
│ SDK Platforms  │  SDK Tools             │
├─────────────────────────────────────────┤
│                                         │
│ ☐ Android Emulator                      │
│ ☐ Android SDK Build-Tools 34.0.0       │
│ ☐ Android SDK Platform-Tools             │
│ ☐ Android SDK Tools                     │
│ ☑ Android SDK Command-line Tools (latest) ← CHECK THIS
│ ☐ Android NDK                           │
│                                         │
│                        [Apply] [Cancel]  │
└─────────────────────────────────────────┘
```

---

## Step 2: Download API 33 System Image

### Still in SDK Manager:
1. Click **SDK Platforms** tab
2. Scroll to **Android 13.0 (API 33)**
3. Click the checkbox (a dialog appears)
4. In the dialog, ensure these are checked:
   - ✅ **Android SDK Platform 33**
   - ✅ **Google APIs Intel x86_64 Atom System Image**
5. Click **OK**
6. Click **Apply**
7. Wait for download (~1-2 GB, 5-10 minutes)
8. Click **Finish**

**Screenshot:**
```
┌─────────────────────────────────────────┐
│ SDK Manager                              │
├─────────────────────────────────────────┤
│ ☐ Android 4.0 (API 14)                  │
│ ☐ Android 4.1 (API 16)                  │
│ ...                                      │
│ ☑ Android 13.0 (API 33)          ← CHECK│
│   Android SDK Platform 33               │
│   Google APIs Intel x86_64 Atom...       │
│ ☐ Android 14.0 (API 34)                 │
│ ...                                      │
│                                         │
│                        [Apply] [Cancel]  │
└─────────────────────────────────────────┘
```

---

## Step 3: Create API 33 Emulator

### In Android Studio:
1. **Tools** → **AVD Manager**
2. Click **Create Virtual Device**
3. Select **Pixel 6** (or any phone)
4. Click **Next**
5. Under "System Image", click **Download** next to **API 33**
6. Click **Next**
7. Click **Finish**

**Alternative: Use the script I created**
- After Steps 1 & 2, run: `setup_api33_emulator.bat`
- It will automatically create and launch the emulator

**Screenshot:**
```
┌─────────────────────────────────────────┐
│ AVD Manager                              │
├─────────────────────────────────────────┤
│                                         │
│  [+ Create Virtual Device]              │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ Medium_Phone_API_36.1    [▶] [⋮]   │ │
│ └─────────────────────────────────────┘ │
│                                         │
└─────────────────────────────────────────┘

Then:

┌─────────────────────────────────────────┐
│ Choose Device                            │
├─────────────────────────────────────────┤
│                                         │
│   ┌─────┐  ┌─────┐  ┌─────┐           │
│   │Pixel│  │Pixel│  │Medium│          │
│   │ 6   │  │ 5   │  │Phone│          │
│   └─────┘  └─────┘  └─────┘           │
│                                         │
│                    [Next] [Cancel]     │
└─────────────────────────────────────────┘
```

---

## Step 4: Launch the Emulator

### After creating the AVD:
1. In AVD Manager, find **Medium_Phone_API_33**
2. Click the **Play button ▶**
3. Wait for emulator to boot (shows Android home screen)

**Screenshot:**
```
┌─────────────────────────────────────────┐
│ AVD Manager                              │
├─────────────────────────────────────────┤
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ Medium_Phone_API_33       [▶][⋮]   │ │
│ │                                    │ │
│ │   Android 13.0                      │ │
│ │   Google APIs x86_64                │ │
│ └─────────────────────────────────────┘ │
│         ▲ Click this Play button         │
└─────────────────────────────────────────┘
```

---

## Step 5: Run UI Tests

### Once emulator is running, run the script:

```bash
setup_api33_emulator.bat
```

### Or manually in terminal:

```bash
cd C:\Users\plner\AndroidStudioProjects\NativeLocal_SLM_App
gradlew.bat :app:connectedDebugAndroidTest
```

---

## Verification

### Check it worked:

```bash
# Should show API 33
adb shell getprop ro.build.version.sdk

# Should run 22 UI tests + 23 existing instrumented tests = 45 total
```

---

## Expected Results

✅ **22 UI tests passing**
✅ **Total tests: 276 (254 + 22)**
✅ **Coverage: 60-70%** (up from 1.73%)

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| SDK Command-line Tools not found | Complete Step 1 |
| System image not found | Complete Step 2 (takes 5-10 min) |
| Emulator won't boot | Use "Cold Boot Now" in AVD Manager |
| Tests still fail | Make sure it's API 33, not 36 (run `adb shell getprop ro.build.version.sdk`) |

---

## Quick Checklist

- [ ] Step 1: Install SDK Command-line Tools
- [ ] Step 2: Download API 33 System Image
- [ ] Step 3: Create API 33 AVD
- [ ] Step 4: Launch API 33 Emulator
- [ ] Step 5: Run `setup_api33_emulator.bat`

**Total time: 15-20 minutes**
