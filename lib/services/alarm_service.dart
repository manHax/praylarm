// lib/services/alarm_service.dart
//
// LOGIKA ALARM:
// Setiap sholat memiliki 2 alarm:
//   [1] 10 menit SEBELUM waktu masuk sholat  → "Segera sholat X"
//   [2] 10 menit SEBELUM waktu sholat HABIS  → "Waktu X hampir habis"

import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prayer_alarm_app/models/prayer_time.dart';
import 'package:prayer_alarm_app/services/device_timezone_service.dart';
import 'package:prayer_alarm_app/services/native_alarm_service.dart';
import 'notification_service.dart';

class ScheduledAlarmRequest {
  final int id;
  final String title;
  final String body;
  final DateTime scheduledTime;
  final String payload;

  const ScheduledAlarmRequest({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledTime,
    required this.payload,
  });
}

class AlarmService {
  static const _defaultMinutesBefore = 10;
  static const _minutesBeforeKey = 'minutes_before';
  static const _notificationsEnabledKey = 'notifications_enabled';
  static const _debugInstantNotificationId = 900001;
  static const _debugScheduledNotificationId = 900002;

  /// ID range untuk alarm:
  /// Sholat index 0-4, alarm type 0=masuk 1=habis
  /// ID = (sholatIndex * 10) + alarmType
  /// Jadi ID: 0,1, 10,11, 20,21, 30,31, 40,41
  static int _alarmId(int sholatIndex, int alarmType) =>
      (sholatIndex * 10) + alarmType;

  static Future<void> initialize() async {
    tz_data.initializeTimeZones();
    final timezoneName = await DeviceTimezoneService.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneName));
    await NotificationService.initialize();
  }

  /// Schedule semua alarm untuk hari ini berdasarkan jadwal sholat
  static Future<void> scheduleAllAlarms(PrayerTimes prayerTimes) async {
    // Batalkan semua alarm lama dulu
    await NotificationService.cancelAll();
    await NativeAlarmService.cancelAllPrayerAlarms();

    final notificationsEnabled = await _notificationsEnabled();
    if (!notificationsEnabled) return;

    final minutesBefore = await _reminderMinutesBefore();
    final requests = buildScheduleRequests(
      prayerTimes: prayerTimes,
      now: DateTime.now(),
      minutesBefore: minutesBefore,
    );

    for (final request in requests) {
      await NotificationService.scheduleNotification(
        id: request.id,
        title: request.title,
        body: request.body,
        scheduledTime: request.scheduledTime,
        payload: request.payload,
      );
    }

    final nativeAlarms = buildNativePrayerAlarms(
      prayerTimes: prayerTimes,
      now: DateTime.now(),
    );
    await NativeAlarmService.schedulePrayerAlarms(nativeAlarms);
  }

  static List<ScheduledAlarmRequest> buildScheduleRequests({
    required PrayerTimes prayerTimes,
    required DateTime now,
    required int minutesBefore,
  }) {
    final requests = <ScheduledAlarmRequest>[];
    final prayers = prayerTimes.allPrayers;

    for (int i = 0; i < prayers.length; i++) {
      final prayer = prayers[i];
      final startTime = _parseTime(prayer.start, baseDate: now);
      final endTime = _parseEndTime(prayer.end, startTime);

      final beforeStart = startTime.subtract(Duration(minutes: minutesBefore));
      if (beforeStart.isAfter(now)) {
        requests.add(
          ScheduledAlarmRequest(
            id: _alarmId(i, 0),
            title: '${prayer.iconEmoji} ${prayer.name} dalam $minutesBefore menit',
            body:
                'Waktu ${prayer.name} (${prayer.arabicName}) akan masuk pukul ${prayer.start}. Siapkan diri untuk sholat.',
            scheduledTime: beforeStart,
            payload: 'prayer_start_${prayer.name}',
          ),
        );
      }

      final beforeEnd = endTime.subtract(Duration(minutes: minutesBefore));
      if (beforeEnd.isAfter(now)) {
        requests.add(
          ScheduledAlarmRequest(
            id: _alarmId(i, 1),
            title: '⚠️ Waktu ${prayer.name} hampir habis!',
            body:
                'Waktu sholat ${prayer.name} (${prayer.arabicName}) akan berakhir pukul ${prayer.end}. Segera sholat!',
            scheduledTime: beforeEnd,
            payload: 'prayer_end_${prayer.name}',
          ),
        );
      }
    }

    return requests;
  }

  static List<NativePrayerAlarm> buildNativePrayerAlarms({
    required PrayerTimes prayerTimes,
    required DateTime now,
  }) {
    final requests = <NativePrayerAlarm>[];
    final prayers = prayerTimes.allPrayers;

    for (int i = 0; i < prayers.length; i++) {
      final prayer = prayers[i];
      final startTime = _parseTime(prayer.start, baseDate: now);
      if (!startTime.isAfter(now)) continue;

      requests.add(
        NativePrayerAlarm(
          id: 1000 + i,
          prayerName: prayer.name,
          arabicName: prayer.arabicName,
          scheduledTime: startTime,
          timeLabel: prayer.start,
        ),
      );
    }

    return requests;
  }

  static Future<int> _reminderMinutesBefore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_minutesBeforeKey) ?? _defaultMinutesBefore;
  }

  static Future<bool> _notificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsEnabledKey) ?? true;
  }

  /// Parse "HH:mm" menjadi DateTime hari ini
  static DateTime _parseTime(String timeStr, {DateTime? baseDate}) {
    // AlAdhan kadang mengembalikan "05:21 (WIB)" — strip timezone suffix
    final clean = timeStr.split(' ').first.trim();
    final parts = clean.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final now = baseDate ?? DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  static DateTime _parseEndTime(String timeStr, DateTime startTime) {
    var endTime = _parseTime(timeStr, baseDate: startTime);
    if (!endTime.isAfter(startTime)) {
      endTime = endTime.add(const Duration(days: 1));
    }
    return endTime;
  }

  /// Getarkan HP saat alarm trigger
  static Future<void> vibrate() async {}

  /// Batalkan semua alarm
  static Future<void> cancelAll() async {
    await NotificationService.cancelAll();
    await NativeAlarmService.cancelAllPrayerAlarms();
  }

  static Future<DateTime> runNotificationSelfTest() async {
    final now = DateTime.now();
    final scheduledAt = now.add(const Duration(seconds: 45));

    await NotificationService.showInstantNotification(
      id: _debugInstantNotificationId,
      title: 'Tes Notifikasi Sekarang',
      body: 'Jika notifikasi ini muncul, trigger langsung berjalan.',
      payload: 'self_test_instant',
    );

    await NotificationService.scheduleNotification(
      id: _debugScheduledNotificationId,
      title: 'Tes Alarm 45 Detik',
      body: 'Jika notifikasi ini muncul, alarm terjadwal berjalan.',
      scheduledTime: scheduledAt,
      payload: 'self_test_scheduled',
    );

    return scheduledAt;
  }

  static Future<DateTime?> runNativeAlarmSelfTest() async {
    return NativeAlarmService.scheduleSelfTestAlarm();
  }

  /// Hitung sholat berikutnya dari jadwal hari ini
  static PrayerEntry? getNextPrayer(PrayerTimes prayerTimes) {
    final now = DateTime.now();
    for (final prayer in prayerTimes.allPrayers) {
      final startTime = _parseTime(prayer.start);
      if (startTime.isAfter(now)) return prayer;
    }
    return null;
  }

  /// Hitung durasi countdown ke sholat berikutnya
  static Duration? getTimeUntilNextPrayer(PrayerTimes prayerTimes) {
    final next = getNextPrayer(prayerTimes);
    if (next == null) return null;
    final startTime = _parseTime(next.start);
    return startTime.difference(DateTime.now());
  }
}
