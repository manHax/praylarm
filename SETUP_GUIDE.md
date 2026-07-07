# 📋 Panduan Setup & Integrasi Lengkap

## 1. Install Dependencies

```bash
flutter pub get
```

---

## 2. Android Setup

### a. Buat notification channel icon
Tambahkan file `ic_notification.png` (putih transparan 24x24dp) di:
```
android/app/src/main/res/drawable/ic_notification.png
```

### b. Widget background drawable
Buat file `android/app/src/main/res/drawable/widget_background.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <solid android:color="#CC0D1B2A" />
    <corners android:radius="16dp" />
</shape>
```

### c. Widget info XML
Buat file `android/app/src/main/res/xml/prayer_times_widget_info.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:initialLayout="@layout/prayer_times_widget"
    android:minWidth="250dp"
    android:minHeight="110dp"
    android:resizeMode="horizontal|vertical"
    android:updatePeriodMillis="1800000"
    android:widgetCategory="home_screen"
    android:previewImage="@mipmap/ic_launcher" />
```

### d. Widget Kotlin receiver
Buat file `android/app/src/main/kotlin/.../PrayerTimesWidget.kt`:
```kotlin
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class PrayerTimesWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (widgetId in appWidgetIds) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val views = RemoteViews(context.packageName, R.layout.prayer_times_widget).apply {
                setTextViewText(R.id.fajr_time, widgetData.getString("fajr", "--:--"))
                setTextViewText(R.id.dhuhr_time, widgetData.getString("dhuhr", "--:--"))
                setTextViewText(R.id.asr_time, widgetData.getString("asr", "--:--"))
                setTextViewText(R.id.maghrib_time, widgetData.getString("maghrib", "--:--"))
                setTextViewText(R.id.isha_time, widgetData.getString("isha", "--:--"))
                setTextViewText(R.id.widget_date, widgetData.getString("date", ""))
                setTextViewText(
                    R.id.next_prayer_label,
                    "Berikutnya: ${widgetData.getString("next_prayer", "")}"
                )
                setTextViewText(
                    R.id.next_prayer_countdown,
                    widgetData.getString("countdown", "")
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
```

---

## 3. iOS Setup

### a. Tambahkan ke Info.plist
Salin semua key dari file `Info.plist.additions.xml` ke `ios/Runner/Info.plist`

### b. App Groups
1. Buka Xcode → Runner target → Signing & Capabilities
2. Tambahkan **App Groups**: `group.com.yourapp.prayeralarm`
3. Aktifkan **Background Modes**: Location updates, Background fetch, Remote notifications, Audio

### c. Widget Extension (iOS 16+)
Buat Swift Widget Extension baru di Xcode dengan nama `PrayerTimesWidget`

---

## 4. Assets yang Diperlukan

```
assets/
├── audio/
│   ├── adzan_fajr.mp3          ← Adzan khusus subuh
│   ├── adzan_normal.mp3        ← Adzan untuk waktu lain
│   └── reminder_beep.mp3       ← Suara untuk alarm "hampir habis"
├── images/
│   └── mosque_bg.png
└── animations/
    └── prayer_animation.json   ← Lottie animation (opsional)
```

> Download audio adzan gratis dari: https://www.islamicfinder.org/

---

## 5. Urutan Inisialisasi di `main.dart`

```
1. tz_data.initializeTimeZones()      ← Timezone data
2. initializeDateFormatting('id_ID')  ← Format tanggal Indonesia
3. NotificationService.initialize()   ← Setup notification channel
4. AlarmService.initialize()          ← Setup timezone lokal
5. BackgroundServiceManager.initialize() ← Mulai background service
6. NotificationService.requestPermission() ← Minta izin notifikasi
```

---

## 6. Testing Alarm

Untuk test alarm tanpa menunggu:
```dart
// Di debug mode, schedule alarm 1 menit dari sekarang
final testTime = DateTime.now().add(const Duration(minutes: 1));
await NotificationService.scheduleNotification(
  id: 999,
  title: '🧪 Test Alarm Sholat',
  body: 'Ini adalah test alarm',
  scheduledTime: testTime,
);
```

---

## 7. Troubleshooting

| Masalah | Solusi |
|---|---|
| Alarm tidak bunyi di Android | Aktifkan "Exact Alarm" permission di Settings → Apps |
| Background service mati | Tambahkan app ke whitelist baterai di pengaturan HP |
| Lokasi tidak akurat | Cek `ACCESS_BACKGROUND_LOCATION` permission |
| Widget tidak update | Panggil `HomeWidget.updateWidget()` setelah data berubah |
| Alarm mati setelah reboot | Pastikan `RECEIVE_BOOT_COMPLETED` permission aktif |
| iOS background tidak jalan | Aktifkan Background App Refresh di Settings iOS |

---

## 8. Catatan Penting

- **Method 11** = Kemenag RI, cocok untuk seluruh Indonesia
- Alarm di-reschedule otomatis setiap pagi jam **03:00**
- Cache lokasi GPS bertahan **6 jam** untuk hemat baterai
- Saat HP restart, background service otomatis nyala kembali
- AlAdhan API **gratis & tanpa API key**
