# Sukoon Launcher — Rebrand Audit & Completion Report

## ✅ REBRAND STATUS: COMPLETE

---

## 🔍 Legacy Branding Found & Fixed

### Category 1: Package ID / Application ID (CRITICAL)
| Location | Old Value | New Value |
|---|---|---|
| `android/app/build.gradle.kts` | `com.example.minimalist_app` | `com.sukoon.launcher` |
| `AndroidManifest.xml` taskAffinity | `com.example.minimalist_app.blocker` | `com.sukoon.launcher.blocker` |
| `android/app/src/main/kotlin/com/example/minimalist_app/` (folder) | `com/example/minimalist_app` | `com/sukoon/launcher` |
| All 4 Kotlin files (package declaration) | `package com.example.minimalist_app` | `package com.sukoon.launcher` |
| `ios/Runner.xcodeproj/project.pbxproj` | `com.example.minimalistApp` | `com.sukoon.launcher` |
| `macos/Runner/Configs/AppInfo.xcconfig` | `com.example.minimalistApp` | `com.sukoon.launcher` |
| `macos/Runner.xcodeproj/project.pbxproj` | `com.example.minimalistApp` | `com.sukoon.launcher` |
| `linux/CMakeLists.txt` | `com.example.minimalist_app` | `com.sukoon.launcher` |

### Category 2: App Name / Labels (CRITICAL)
| Location | Old Value | New Value |
|---|---|---|
| `AndroidManifest.xml` android:label | `Camel` | `Sukoon` |
| `lib/main.dart` MaterialApp title | `Camel Launcher` | `Sukoon Launcher` |
| `ios/Runner/Info.plist` CFBundleDisplayName | `Minimalist App` | `Sukoon Launcher` |
| `ios/Runner/Info.plist` CFBundleName | `minimalist_app` | `Sukoon Launcher` |
| `web/manifest.json` name/short_name | `minimalist_app` | `Sukoon Launcher` |
| `web/index.html` title & apple-mobile-web-app-title | `minimalist_app` | `Sukoon Launcher` |
| `linux/runner/my_application.cc` window title | `minimalist_app` | `Sukoon Launcher` |
| `windows/runner/main.cpp` window title | `minimalist_app` | `Sukoon Launcher` |
| `windows/runner/Runner.rc` all descriptions | `minimalist_app` | `Sukoon Launcher` |
| `macos/Runner/Configs/AppInfo.xcconfig` PRODUCT_NAME | `minimalist_app` | `Sukoon Launcher` |
| `pubspec.yaml` name | `minimalist_app` | `sukoon_launcher` |

### Category 3: MethodChannel Strings (CRITICAL — must match both Kotlin + Dart sides)
| Channel | Files |
|---|---|
| `com.example.minimalist_app/launcher` | `MainActivity.kt`, `settings_screen.dart`, `onboarding_screen.dart` |
| `com.minimalist.launcher/usage_stats` | `MainActivity.kt` |
| `com.minimalist.launcher/app_blocker` | `MainActivity.kt`, `native_app_blocker_service.dart`, `zen_mode_entry_screen.dart`, `zen_mode_active_screen.dart`, `zen_mode_provider.dart` |
| `com.minimalist.launcher/dnd` | `MainActivity.kt`, `zen_mode_entry_screen.dart`, `zen_mode_provider.dart`, `deen_mode_provider.dart` |
| `com.minimalist.launcher/dhikr_notification` | `notification_dhikr_service.dart` |
| `com.minimalist.launcher/apps` | `zen_mode_active_screen.dart`, `zen_mode_provider.dart` |

### Category 4: User-Facing Strings in Dart
| File | Old String |
|---|---|
| `onboarding_screen.dart:724` | `'CAMEL PRO'` |
| `onboarding_screen.dart:887` | `'Set Camel Launcher as your\ndefault home screen'` |
| `onboarding_screen.dart:924` | `'Select "Camel Launcher"'` |
| `privacy_policy_screen.dart:63` | `'Camel Launcher ("we", "our"...'` |
| `privacy_policy_screen.dart:149` | `camellauncher@gmail.com` |
| `weekly_barakah_report.dart:146` | `#CamelLauncher` |
| `hadith_dua_models.dart:363,464` | `'Shared via Camel Launcher 🐪'` |
| `camel_coin_store_screen.dart` (multiple) | `Camel Store`, `Camel Coins` |
| `settings_screen.dart` (multiple) | `Camel Store`, `Camel Coins` |
| `daily_challenge_card.dart:229` | `Camel Coins earned!` |
| `premium_paywall_screen.dart:190` | promo code `'CAMEL'` |
| `app_filter_utils.dart:603` | self-filter `com.example.minimalist_app` |
| `zen_mode_provider.dart:123` | self-filter `com.example.minimalist_app` |

### Category 5: Dart Class/Widget Names (Internal code references)
| Old Name | New Name | File |
|---|---|---|
| `MinimalistLauncherApp` | `SukoonLauncherApp` | `lib/main.dart` |
| `CamelColors` | `SukoonColors` | `lib/providers/theme_provider.dart` |
| `CamelCoinState` | `SukoonCoinState` | `lib/providers/camel_coin_provider.dart` |
| `CamelCoinNotifier` | `SukoonCoinNotifier` | `lib/providers/camel_coin_provider.dart` |
| `CamelStore` | `SukoonStore` | `lib/providers/camel_coin_provider.dart` |
| `CamelCoinStoreScreen` | `SukoonCoinStoreScreen` | `lib/screens/camel_coin_store_screen.dart` |
| `camelCoinProvider` | `sukoonCoinProvider` | `lib/providers/camel_coin_provider.dart` |
| `coinBalanceProvider` | (keep — generic) | |
| File: `camel_coin_provider.dart` | → `sukoon_coin_provider.dart` | |
| File: `camel_coin_store_screen.dart` | → `sukoon_coin_store_screen.dart` | |

### Category 6: Theme Color References
| Location | Old Name | New Name |
|---|---|---|
| `theme_provider.dart` | `ThemeColors.camel` | `ThemeColors.sukoon` |
| `theme_provider.dart` | `name: 'Camel'` | `name: 'Sukoon'` |
| Various widget files | `_camelBrown` variable | `_warmBrown` (or keep as color constant) |

### Category 7: Platform Config Files (Non-critical but needed)
| File | Change |
|---|---|
| `windows/CMakeLists.txt` | project name + BINARY_NAME |
| `macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` | `minimalist_app.app` refs |
| `macos/Runner.xcodeproj/project.pbxproj` | `minimalist_app.app` refs |

### Category 8: Legacy Documentation (.md files at root)
30+ `.md` files with legacy references (`Camel Launcher`, `minimalist_app`, `aheteshamq25`). These are internal docs, not shipped in the APK.

### Category 9: privacy_policy.html
Contains `Minimalist Launcher` branding — needs update for Play Store.

---

## ✅ Rebrand Execution Plan

**New branding:**
- App name: **Sukoon Launcher**
- Display label: **Sukoon**
- Package: `com.sukoon.launcher`
- Dart package: `sukoon_launcher`
- Internal coin brand: **Sukoon Coins** / **Sukoon Store**
- Pro tier: **Sukoon Pro**
- Promo code: `SUKOON`
- Email: `sukoonlauncher@gmail.com` *(update if needed)*
- Hashtag: `#SukoonLauncher`

---

## ✅ Rebrand Completion Checklist

### Package & Build Config
- [x] `pubspec.yaml` → `name: sukoon_launcher`
- [x] `android/app/build.gradle.kts` → `namespace` & `applicationId` = `com.sukoon.launcher`
- [x] `AndroidManifest.xml` → `android:label="Sukoon"`, taskAffinity updated
- [x] Kotlin package moved: `com/example/minimalist_app/` → `com/sukoon/launcher/`
- [x] All 4 Kotlin files: `package com.sukoon.launcher`
- [x] iOS `Info.plist` → `CFBundleDisplayName: Sukoon Launcher`
- [x] iOS `project.pbxproj` → `PRODUCT_BUNDLE_IDENTIFIER: com.sukoon.launcher`
- [x] macOS `AppInfo.xcconfig` → `PRODUCT_NAME = Sukoon Launcher`, `PRODUCT_BUNDLE_IDENTIFIER = com.sukoon.launcher`
- [x] macOS `project.pbxproj` → all refs updated
- [x] Linux `CMakeLists.txt` → binary + application ID updated
- [x] Linux `my_application.cc` → window title updated
- [x] Windows `CMakeLists.txt` → project + binary updated
- [x] Windows `main.cpp` → window title updated
- [x] Windows `Runner.rc` → all descriptions + exe name updated
- [x] Web `manifest.json` → name, short_name, description updated
- [x] Web `index.html` → title, apple-mobile-web-app-title updated

### MethodChannel Strings (Kotlin ↔ Dart)
- [x] `com.sukoon.launcher/launcher` (was `com.example.minimalist_app/launcher`)
- [x] `com.sukoon.launcher/usage_stats` (was `com.minimalist.launcher/usage_stats`)
- [x] `com.sukoon.launcher/app_blocker` (was `com.minimalist.launcher/app_blocker`)
- [x] `com.sukoon.launcher/dnd` (was `com.minimalist.launcher/dnd`)
- [x] `com.sukoon.launcher/dhikr_notification` (was `com.minimalist.launcher/dhikr_notification`)
- [x] `com.sukoon.launcher/apps` (was `com.minimalist.launcher/apps`)

### Dart Source Code
- [x] `MinimalistLauncherApp` → `SukoonLauncherApp`
- [x] `CamelColors` → `SukoonColors`
- [x] `CamelCoinState` → `SukoonCoinState`
- [x] `CamelCoinNotifier` → `SukoonCoinNotifier`
- [x] `CamelStore` → `SukoonStore`
- [x] `CamelCoinStoreScreen` → `SukoonCoinStoreScreen`
- [x] `camelCoinProvider` → `sukoonCoinProvider`
- [x] `ThemeColors.camel` → `ThemeColors.sukoon`
- [x] `_camelBrown` → `_warmBrown`
- [x] `camelBrown` → `warmBrown`
- [x] `camelMilk` → `softCream`
- [x] File renamed: `camel_coin_provider.dart` → `sukoon_coin_provider.dart`
- [x] File renamed: `camel_coin_store_screen.dart` → `sukoon_coin_store_screen.dart`
- [x] All imports updated to match new file names

### User-Facing Strings
- [x] App title: `Sukoon Launcher`
- [x] Onboarding: `SUKOON PRO`, `Set Sukoon Launcher as your default...`, `Select "Sukoon Launcher"`
- [x] Privacy policy: `Sukoon Launcher ("we", "our"...)`
- [x] Contact email: `sukoonlauncher@gmail.com`
- [x] Coins: `Sukoon Coins` (all references)
- [x] Store: `Sukoon Store` (all references)
- [x] Hashtag: `#SukoonLauncher`
- [x] Shared via text: `Shared via Sukoon Launcher ☪️`
- [x] Promo code: `SUKOON`
- [x] Zen Mode permission dialogs: `find "Sukoon" in the list`
- [x] Notification title: `☪️ Focus Mode Active`
- [x] Self-filter: `pkg != 'com.sukoon.launcher'`

### HTML/Static
- [x] `privacy_policy.html` → all `Sukoon Launcher` branding

### Data Integrity
- [x] Hive box name `camel_coins` preserved (to keep existing user data)
- [x] No layout/UI/UX changes made — ZERO visual modifications

### Files Cleaned
- [x] Old Kotlin directory `com/example/minimalist_app/` deleted
- [x] Old Dart files `camel_coin_provider.dart`, `camel_coin_store_screen.dart` removed (renamed)

### Test File
- [x] `test/widget_test.dart` → imports `sukoon_launcher/main.dart`, uses `SukoonLauncherApp`

---

## ⚠️ Items to Address Manually

1. **App icon**: Update `android/app/src/main/res/mipmap-*/ic_launcher.png` and iOS `Assets.xcassets` with new Sukoon branding icon
2. **Splash screen**: If there's a camel-themed splash, replace the asset
3. **Play Store listing**: Update store title, description, screenshots
4. **Contact email**: Verify `sukoonlauncher@gmail.com` is set up, or change to your preferred email
5. **Privacy policy URL**: Re-host at new GitHub Pages URL (was `aheteshamq25.github.io/minimalist_app`)
6. **Root `.md` documentation files**: 30+ legacy docs at project root reference old branding — these are dev-only and don't ship in APK, but can be cleaned up if desired
7. **`.claude/` and `.agent/` folders**: Internal AI session docs with old branding — safe to delete
8. **Run `flutter pub get`** to regenerate lock file with new package name
9. **Run `flutter clean && flutter build apk`** to verify full build

