# 🕌 Prayer Alarm App — Arsitektur & Implementasi Flutter

## Stack & Package

| Kebutuhan | Package |
|---|---|
| Background service | `flutter_background_service` |
| GPS / Lokasi | `geolocator` |
| API Jadwal Sholat | `http` → AlAdhan API |
| Alarm (suara adzan) | `flutter_local_notifications` + `android_alarm_manager_plus` |
| Getaran | `vibration` |
| Widget homescreen | `home_widget` |
| Timezone | `flutter_timezone` + `timezone` |
| Storage lokal | `shared_preferences` |
| Audio adzan | `just_audio` |

---

## Struktur Folder

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── constants.dart
│   ├── prayer_methods.dart
│   └── utils.dart
├── services/
│   ├── background_service.dart      ← Background isolate utama
│   ├── location_service.dart        ← Deteksi GPS
│   ├── prayer_api_service.dart      ← AlAdhan API
│   ├── alarm_service.dart           ← Schedule alarm
│   ├── notification_service.dart    ← Push notification
│   └── audio_service.dart           ← Putar adzan
├── models/
│   ├── prayer_time.dart
│   └── alarm_config.dart
├── ui/
│   ├── home_screen.dart
│   ├── settings_screen.dart
│   └── widgets/
│       ├── prayer_card.dart
│       └── next_prayer_banner.dart
└── widget/
    └── home_widget_provider.dart    ← Homescreen widget
```

---

## Alur Kerja Utama

```
App Start
   │
   ▼
[Background Service mulai]
   │
   ▼
[LocationService] → Ambil koordinat GPS (cache 6 jam)
   │
   ▼
[PrayerApiService] → GET AlAdhan API /timings
   │
   ▼
[AlarmService] → Schedule 10 alarm per hari:
   │               • 5x "10 menit sebelum sholat masuk"
   │               • 5x "10 menit sebelum waktu sholat habis"
   ▼
[Trigger Alarm]
   ├── NotificationService → Push notification
   ├── AudioService → Putar adzan
   ├── Vibration → Getaran
   └── HomeWidgetProvider → Update widget
```

---

## Logika Waktu Alarm

```
Fajr     → alarm1: Fajr - 10 mnt
           alarm2: Sunrise - 10 mnt  (waktu fajr habis sebelum sunrise)

Dhuhr    → alarm1: Dhuhr - 10 mnt
           alarm2: Asr - 10 mnt

Asr      → alarm1: Asr - 10 mnt
           alarm2: Maghrib - 10 mnt

Maghrib  → alarm1: Maghrib - 10 mnt
           alarm2: Isha - 10 mnt

Isha     → alarm1: Isha - 10 mnt
           alarm2: Midnight - 10 mnt (atau +90 mnt dari Isha)
```

---

## Perizinan yang Dibutuhkan

### Android (AndroidManifest.xml)
- `ACCESS_FINE_LOCATION`
- `ACCESS_BACKGROUND_LOCATION`
- `RECEIVE_BOOT_COMPLETED`
- `SCHEDULE_EXACT_ALARM`
- `USE_EXACT_ALARM`
- `VIBRATE`
- `WAKE_LOCK`
- `FOREGROUND_SERVICE`
- `POST_NOTIFICATIONS`

### iOS (Info.plist)
- `NSLocationAlwaysAndWhenInUseUsageDescription`
- `NSLocationWhenInUseUsageDescription`
- `UIBackgroundModes`: location, fetch, remote-notification, audio
