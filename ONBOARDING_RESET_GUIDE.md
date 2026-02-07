# 🔄 Reset Onboarding — Testing Guide

## Quick Summary
After implementing the onboarding system, you can test it by resetting the app to its first-launch state using one of the methods below.

---

## ✨ **Method 1: Use the Debug Button (EASIEST)**

A floating orange bug icon 🐛 is now visible in the bottom-right corner of your launcher.

### Steps:
1. **Long-press** the orange debug button (bottom-right corner)
2. Select one of the reset options:
   - **Reset Onboarding** — Only resets the onboarding flag (keeps all other data)
   - **Clear All Data** — Nuclear option, deletes everything
3. **Close and restart** the app
4. Onboarding will show on next launch! ✅

**Location:** Bottom-right corner of the launcher (visible on all pages)

---

## 🔧 **Method 2: ADB Clear App Data (RECOMMENDED)**

This completely resets the app to factory state.

### Steps:
```bash
# 1. Stop the app (if running)
# 2. Clear all app data
adb shell pm clear com.example.minimalist_app

# 3. Restart the app
flutter run --release
```

**Result:** 
- ✅ All Hive databases deleted
- ✅ All settings reset
- ✅ Onboarding shows on launch

---

## 🎯 **Method 3: ADB Delete Specific Files (SURGICAL)**

Delete only the onboarding Hive box while keeping other data intact.

### Steps:
```bash
# Delete Hive boxes
adb shell run-as com.example.minimalist_app rm -rf /data/data/com.example.minimalist_app/app_flutter/*.hive
adb shell run-as com.example.minimalist_app rm -rf /data/data/com.example.minimalist_app/app_flutter/*.lock

# Restart app
flutter run --release
```

**Result:**
- ✅ Onboarding reset
- ⚠️ Other Hive data also deleted (challenges, productivity, etc.)

---

## 🔍 **Method 4: Manual Code Edit (TEMPORARY OVERRIDE)**

Temporarily force onboarding to always show.

### Steps:
1. Open `lib/main.dart`
2. Find the `_checkOnboardingStatus()` function (around line 129):
   ```dart
   Future<bool> _checkOnboardingStatus() async {
     final box = await Hive.openBox('app_prefs');
     return box.get('onboarding_completed', defaultValue: false);
   }
   ```
3. Change to:
   ```dart
   Future<bool> _checkOnboardingStatus() async {
     final box = await Hive.openBox('app_prefs');
     return false; // 🔧 Always show onboarding
   }
   ```
4. Hot reload/restart app
5. **Remember to revert this change after testing!**

---

## 📱 **Verify Reset Worked**

After using any method:
1. Close the app completely
2. Relaunch the app
3. You should see the **5-page onboarding flow**:
   - 🐪 Welcome screen
   - 📱 App selection
   - 🎯 Productivity features
   - 🔔 Notifications permission
   - 📊 Usage stats permission

---

## 🗑️ **What Gets Reset**

### Debug Button → "Reset Onboarding":
- ✅ `onboarding_completed` flag deleted
- ❌ All other data kept (settings, apps, challenges, etc.)

### Debug Button → "Clear All Data":
- ✅ All Hive boxes deleted:
  - `app_prefs`, `installed_apps`, `app_block_rules`
  - `productivity_events`, `productivity_goals`, `daily_challenges`
  - `pomodoro_sessions`, `read_hadiths`

### ADB `pm clear`:
- ✅ All app data deleted (equivalent to uninstall+reinstall)
- ✅ Shared preferences cleared
- ✅ All files in app directory deleted

---

## 🚀 **Production Notes**

**Before releasing to production:**
1. Remove the `DebugResetButton()` from `launcher_shell.dart` (line ~237)
2. Or wrap it in a conditional:
   ```dart
   if (kDebugMode) const DebugResetButton(),
   ```
3. Delete or comment out the `debug_reset_helper.dart` file

---

## 🛠️ **Files Modified**

- **Created:** `lib/utils/debug_reset_helper.dart` — Debug reset utilities
- **Modified:** `lib/screens/launcher_shell.dart` — Added debug button

---

## 💡 **Tips**

1. **Use Method 1** for quick testing during development
2. **Use Method 2** for complete reset testing (most realistic)
3. **The debug button is intentionally orange** 🟠 so you remember to remove it before production
4. **Long-press duration:** ~500ms (standard Android long-press)

---

**Happy Testing! 🎉**
