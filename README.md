# Praylarm (Prayer Alarm App)

Praylarm is a highly automated, location-aware Flutter application that provides prayer times, configurable full-screen Android native alarms, push notifications, and a Khatam Quran planner.

## 📥 Download APK
Download the latest production-ready APK from the `releases` directory:
- [Praylarm v1.1.0+3 (APK)](releases/app-release.apk)

---

## 🤖 AI Context & Architecture (For AI Assistants & Developers)

This section contains critical context to help AI assistants (and human developers) understand the codebase structure and specific implementation choices.

### 1. Tech Stack
- **Framework:** Flutter (Dart)
- **Native Platform:** Android (Kotlin)
- **Core APIs:** AlAdhan API (Prayer times calculation)

### 2. Core Architecture & Services
The app relies heavily on background services and native Android integrations to guarantee alarms ring exactly on time even when the app is killed or the device is locked.

- **`PrayerApiService`**: Fetches prayer times from `api.aladhan.com`.
  - **Important Context:** Uses `school=0` (Shafi'i) for Asr calculation by default, which is the standard in Indonesia.
- **`LocationService` / `LocationRefreshService`**: Uses `geolocator` to track device location.
- **`AlarmService` & `NativeAlarmService`**: 
  - Uses `android_alarm_manager_plus` for scheduling exact background tasks.
  - Triggers a **Native Android Activity** (`PrayerAlarmActivity.kt`) which implements wake locks (`FLAG_KEEP_SCREEN_ON`, `FLAG_TURN_SCREEN_ON`, `FLAG_SHOW_WHEN_LOCKED`). This bypasses standard Android background restrictions to ring loudly and show a full-screen alarm overlay.
  - Auto-reschedules alarms on device boot via `PrayerAlarmRescheduleReceiver.kt`.
- **`AlarmPreferenceService`**: Allows granular configuration per prayer (Fajr, Dhuhr, Asr, Maghrib, Isha) mapping to 3 modes: `AlarmMode.alarm` (Full native ring), `AlarmMode.push` (Silent notification), and `AlarmMode.off`.
- **`ThemeService`**: Manages a dynamic, premium Light/Dark mode. State relies on `Provider`/`ChangeNotifier` accessible via `context.colors`.

### 3. Key UI Screens (`lib/ui/`)
- `home_screen.dart`: Main dashboard displaying a countdown to the next prayer, location status, and dynamic header gradients.
- `settings_screen.dart`: Global configurations with **Auto-save** implementation. Any state changes here trigger immediate side-effects (e.g., rescheduling alarms) without needing a manual "Save" button.
- `alarm_preferences_screen.dart`: Configures the `AlarmMode` for individual prayer times.
- `khatam_planner_screen.dart`: A specialized tool to plan Quran readings by dividing pages/ayats across days and prayer slots.

### 4. Known Workarounds & Hacks
- **UI Padding:** `ListView` components across screens use `EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.paddingOf(context).bottom)` to ensure scrollable content goes underneath the transparent Android navigation bar instead of being clipped or overwritten by fixed paddings.

---

## ✨ Features
- **Auto-Location Detection:** Adjusts calculation automatically as you travel.
- **Native Wake-lock Alarms:** Rings and overrides the lock screen exactly like a native alarm clock.
- **Per-Prayer Configurations:** Choose between ringing, push notification, or silent for every single prayer time.
- **Premium Dark Mode:** Adaptive and sleek design out of the box.
- **Khatam Planner:** Easily divide your reading targets over customizable durations.

## 🛠️ How to Build
1. Ensure [Flutter SDK](https://docs.flutter.dev/get-started/install) is installed on your machine.
2. Clone the repository and run:
   ```bash
   flutter pub get
   ```
3. Run the app directly to your device:
   ```bash
   flutter run --release
   ```
4. Build APK:
   ```bash
   flutter build apk --release
   ```

*Note: The app may generate Gradle warnings regarding Kotlin Gradle Plugin (KGP) deprecation from community plugins (like `android_alarm_manager_plus`), but these warnings do not affect the successful build output.*
