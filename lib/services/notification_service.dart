// lib/services/notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static const prayerAlarmChannelId = 'prayer_alarm_channel';
  static const prayerAlarmChannelName = 'Alarm Sholat';
  static const prayerAlarmChannelDescription = 'Pengingat waktu sholat';
  static const backgroundServiceChannelId = 'prayer_bg_service';
  static const backgroundServiceChannelName = 'Prayer Background Service';
  static const backgroundServiceChannelDescription =
      'Layanan latar belakang untuk pembaruan jadwal sholat';

  static Future<void> initialize() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Buat notification channel Android
    await createAndroidChannel(
      id: prayerAlarmChannelId,
      name: prayerAlarmChannelName,
      description: prayerAlarmChannelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );

    _initialized = true;
  }

  static Future<void> createAndroidChannel({
    required String id,
    required String name,
    required String description,
    Importance importance = Importance.defaultImportance,
    bool playSound = true,
    bool enableVibration = true,
    bool enableLights = true,
  }) async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          AndroidNotificationChannel(
            id,
            name,
            description: description,
            importance: importance,
            playSound: playSound,
            enableVibration: enableVibration,
            enableLights: enableLights,
          ),
        );
  }

  /// Schedule notifikasi pada waktu tertentu
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    await initialize();

    final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);
    final scheduleMode = await _resolveAndroidScheduleMode();

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          prayerAlarmChannelId,
          prayerAlarmChannelName,
          channelDescription: prayerAlarmChannelDescription,
          importance: Importance.max,
          priority: Priority.high,
          ticker: title,
          icon: '@mipmap/ic_launcher',
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          styleInformation: BigTextStyleInformation(body),
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true, // tampil saat layar terkunci
          visibility: NotificationVisibility.public,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  /// Batalkan semua alarm sholat
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Batalkan alarm tertentu by ID
  static Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  static Future<void> showPinnedNotification({
    required String title,
    required String body,
  }) async {
    await initialize();
    
    // Gunakan channel khusus untuk pinned notification agar tidak bunyi tiap diupdate
    const channelId = 'pinned_prayer_channel';
    const channelName = 'Jadwal Sholat (Pinned)';
    
    await createAndroidChannel(
      id: channelId,
      name: channelName,
      description: 'Menampilkan jadwal sholat secara terus menerus',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
      enableLights: false,
    );

    await _plugin.show(
      999, // ID khusus untuk pinned notification
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: 'Menampilkan jadwal sholat secara terus menerus',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true, // Tidak bisa diswipe (pinned)
          autoCancel: false,
          showWhen: false,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
    );
  }

  static Future<void> cancelPinnedNotification() async {
    await _plugin.cancel(999);
  }

  static Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialize();

    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          prayerAlarmChannelId,
          prayerAlarmChannelName,
          channelDescription: prayerAlarmChannelDescription,
          importance: Importance.max,
          priority: Priority.high,
          ticker: title,
          icon: '@mipmap/ic_launcher',
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          styleInformation: BigTextStyleInformation(body),
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          visibility: NotificationVisibility.public,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      payload: payload,
    );
  }

  static Future<int> pendingNotificationCount() async {
    await initialize();
    final pending = await _plugin.pendingNotificationRequests();
    return pending.length;
  }

  static void _onNotificationTapped(NotificationResponse response) {
    // Bisa navigasi ke halaman tertentu
  }

  /// Request permission (Android 13+)
  static Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  static Future<bool> requestExactAlarmPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestExactAlarmsPermission() ?? false;
  }

  static Future<bool> canScheduleExactNotifications() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    return await android?.canScheduleExactNotifications() ?? false;
  }

  static Future<AndroidScheduleMode> _resolveAndroidScheduleMode() async {
    final canScheduleExact = await canScheduleExactNotifications();
    if (canScheduleExact) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }
}
