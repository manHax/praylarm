// lib/services/background_service.dart
//
// Background service berjalan terus di background untuk:
// 1. Deteksi lokasi setiap pagi jam 03:00
// 2. Refresh jadwal sholat dari API
// 3. Re-schedule semua alarm untuk hari ini
// 4. Update homescreen widget

import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'location_service.dart';
import 'prayer_api_service.dart';
import 'alarm_service.dart';
import 'home_widget_service.dart';

const _foregroundNotificationTitle = 'Prayer Alarm Aktif';
const _foregroundNotificationContent = 'Memantau jadwal sholat';

@pragma('vm:entry-point')
Future<void> backgroundServiceOnStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((_) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((_) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((_) {
    service.stopSelf();
  });

  service.on('forceRefresh').listen((_) async {
    await BackgroundServiceManager.refreshPrayerSchedule(service);
    if (service is AndroidServiceInstance) {
      await BackgroundServiceManager.updateForegroundNotification(service);
    }
  });

  await AlarmService.initialize();
  await BackgroundServiceManager.refreshPrayerSchedule(service);

  Timer.periodic(const Duration(minutes: 30), (_) async {
    final now = DateTime.now();

    final prefs = await SharedPreferences.getInstance();
    final lastRefreshTime = prefs.getInt('last_refresh');
    final lastRefreshDate = lastRefreshTime != null
        ? DateTime.fromMillisecondsSinceEpoch(lastRefreshTime)
        : null;

    final isSameDay = lastRefreshDate != null &&
        lastRefreshDate.year == now.year &&
        lastRefreshDate.month == now.month &&
        lastRefreshDate.day == now.day;

    // Refresh if not yet refreshed today, and it's already past 1:00 AM
    if (!isSameDay && now.hour >= 1) {
      await BackgroundServiceManager.refreshPrayerSchedule(service);
    }

    if (service is AndroidServiceInstance) {
      await BackgroundServiceManager.updateForegroundNotification(service);
    }
  });
}

@pragma('vm:entry-point')
Future<bool> backgroundServiceOnIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
class BackgroundServiceManager {
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    if (await service.isRunning()) {
      return;
    }

    await NotificationService.initialize();
    await NotificationService.createAndroidChannel(
      id: NotificationService.backgroundServiceChannelId,
      name: NotificationService.backgroundServiceChannelName,
      description: NotificationService.backgroundServiceChannelDescription,
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
      enableLights: false,
    );

    await service.configure(
      // ── Android ───────────────────────────────────────────────────────────
      androidConfiguration: AndroidConfiguration(
        onStart: backgroundServiceOnStart,
        autoStart: false,
        autoStartOnBoot: true,
        isForegroundMode: true,
        notificationChannelId: NotificationService.backgroundServiceChannelId,
        initialNotificationTitle: _foregroundNotificationTitle,
        initialNotificationContent: _foregroundNotificationContent,
        foregroundServiceNotificationId: 999,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      // ── iOS ───────────────────────────────────────────────────────────────
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: backgroundServiceOnStart,
        onBackground: backgroundServiceOnIosBackground,
      ),
    );

    await service.startService();
  }

  @pragma('vm:entry-point')
  static Future<void> refreshPrayerSchedule(ServiceInstance service) async {
    try {
      // 1. Ambil lokasi
      final location = await LocationService.getLocationSilently();
      if (location == null) return;

      // 2. Ambil jadwal sholat
      final prayerTimes = await PrayerApiService.getPrayerTimes(
        lat: location.lat,
        lng: location.lng,
      );

      // 3. Schedule semua alarm
      await AlarmService.scheduleAllAlarms(prayerTimes);

      // 4. Update homescreen widget
      await HomeWidgetService.update(prayerTimes);

      // 5. Simpan timestamp terakhir refresh
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'last_refresh',
        DateTime.now().millisecondsSinceEpoch,
      );

      // Kirim event ke UI jika app sedang terbuka
      service.invoke('prayerTimesUpdated', prayerTimes.toJson());
    } catch (e) {
      // Silent fail — akan dicoba lagi 30 menit kemudian
    }
  }

  @pragma('vm:entry-point')
  static Future<void> updateForegroundNotification(
      AndroidServiceInstance service) async {
    try {
      final location = await LocationService.getLocationSilently();
      if (location == null) return;

      final prayerTimes = await PrayerApiService.getPrayerTimes(
        lat: location.lat,
        lng: location.lng,
      );

      final next = AlarmService.getNextPrayer(prayerTimes);
      final duration = AlarmService.getTimeUntilNextPrayer(prayerTimes);

      if (next != null && duration != null) {
        final hours = duration.inHours;
        final minutes = duration.inMinutes % 60;
        final countdownStr = hours > 0
            ? '$hours jam $minutes menit'
            : '$minutes menit';

        service.setForegroundNotificationInfo(
          title: _foregroundNotificationTitle,
          content: '${next.name} pukul ${next.start} (dalam $countdownStr)',
        );
      }
    } catch (_) {}
  }

  /// Panggil dari UI untuk memaksa refresh jadwal
  @pragma('vm:entry-point')
  static Future<void> forceRefresh() async {
    final service = FlutterBackgroundService();
    service.invoke('forceRefresh');
  }

  @pragma('vm:entry-point')
  static Future<bool> isRunning() async {
    return FlutterBackgroundService().isRunning();
  }
}
