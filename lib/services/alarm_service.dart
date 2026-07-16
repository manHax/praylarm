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
import 'package:prayer_alarm_app/services/prayer_api_service.dart';
import 'package:prayer_alarm_app/services/alarm_preference_service.dart';
import 'package:prayer_alarm_app/models/alarm_mode.dart';
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

class _AlarmTargetInfo {
  final String name;
  final String arabicName;
  final String iconEmoji;
  final String start;
  final String? end;

  const _AlarmTargetInfo({
    required this.name,
    required this.arabicName,
    required this.iconEmoji,
    required this.start,
    this.end,
  });
}

class AlarmService {
  static const _defaultMinutesBefore = 10;
  static const _minutesBeforeKey = 'minutes_before';
  static const _notificationsEnabledKey = 'notifications_enabled';
  static const _debugInstantNotificationId = 900001;
  static const _debugScheduledNotificationId = 900002;
  static Future<void>? _initializeFuture;

  static const _namesMap = [
    'Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha',
    'Imsak', 'Syuruq', 'Dhuha', 'Tengah Malam', 'Tahajud Utama'
  ];

  static int _getAlarmIdForName(String name, int type, {bool isTomorrow = false}) {
    int index = _namesMap.indexOf(name);
    if (index == -1) index = 99;
    return (index * 10) + type + (isTomorrow ? 200 : 0);
  }

  static Future<void> initialize() async {
    _initializeFuture ??= _initializeInternal();
    await _initializeFuture;
  }

  static Future<void> _initializeInternal() async {
    tz_data.initializeTimeZones();
    final timezoneName = await DeviceTimezoneService.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneName));
    await NotificationService.initialize();
  }

  /// Schedule semua alarm untuk hari ini dan besok berdasarkan jadwal sholat
  static Future<void> scheduleAllAlarms(PrayerTimes prayerTimes) async {
    await initialize();

    // Batalkan semua alarm lama dulu
    await NotificationService.cancelAll();
    await NativeAlarmService.cancelAllPrayerAlarms();

    final notificationsEnabled = await _notificationsEnabled();
    if (!notificationsEnabled) return;

    final minutesBefore = await _reminderMinutesBefore();
    
    final allNames = [
      ...prayerTimes.allPrayers.map((p) => p.name),
      ...prayerTimes.relatedTimes.map((r) => r.name),
    ];
    final modes = await AlarmPreferenceService.getAllModes(allNames);

    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));

    PrayerTimes tomorrowPrayerTimes;
    try {
      tomorrowPrayerTimes = await PrayerApiService.getTomorrowPrayerTimes(
        lat: prayerTimes.latitude,
        lng: prayerTimes.longitude,
      );
    } catch (_) {
      tomorrowPrayerTimes = prayerTimes; // fallback
    }

    final requests = buildScheduleRequests(
      prayerTimes: prayerTimes,
      modes: modes,
      now: now,
      minutesBefore: minutesBefore,
    );
    final tomorrowRequests = buildScheduleRequests(
      prayerTimes: tomorrowPrayerTimes,
      modes: modes,
      now: now,
      minutesBefore: minutesBefore,
      isTomorrow: true,
    );

    for (final request in [...requests, ...tomorrowRequests]) {
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
      modes: modes,
      now: now,
    );
    final tomorrowNativeAlarms = buildNativePrayerAlarms(
      prayerTimes: tomorrowPrayerTimes,
      modes: modes,
      now: now,
      isTomorrow: true,
    );
    await NativeAlarmService.schedulePrayerAlarms([...nativeAlarms, ...tomorrowNativeAlarms]);
  }

  static List<ScheduledAlarmRequest> buildScheduleRequests({
    required PrayerTimes prayerTimes,
    required Map<String, AlarmMode> modes,
    required DateTime now,
    required int minutesBefore,
    bool isTomorrow = false,
  }) {
    final requests = <ScheduledAlarmRequest>[];
    final baseDate = isTomorrow ? now.add(const Duration(days: 1)) : now;

    // Kumpulkan semua target (sholat wajib + waktu terkait)
    final targets = [
      ...prayerTimes.allPrayers.map((p) => _AlarmTargetInfo(
            name: p.name,
            arabicName: p.arabicName,
            iconEmoji: p.iconEmoji,
            start: p.start,
            end: p.end,
          )),
      ...prayerTimes.relatedTimes.map((r) => _AlarmTargetInfo(
            name: r.name,
            arabicName: r.name,
            iconEmoji: r.iconEmoji,
            start: r.time,
            end: null,
          )),
    ];

    for (final target in targets) {
      final mode = modes[target.name] ?? AlarmMode.off;
      if (mode == AlarmMode.off) continue;

      // AlarmMode.push atau AlarmMode.alarm tetap mendapatkan notifikasi push pengingat
      final startTime = _parseTime(target.start, baseDate: baseDate);

      final beforeStart = startTime.subtract(Duration(minutes: minutesBefore));
      if (beforeStart.isAfter(now)) {
        requests.add(
          ScheduledAlarmRequest(
            id: _getAlarmIdForName(target.name, 0, isTomorrow: isTomorrow),
            title: '${target.iconEmoji} ${target.name} dalam $minutesBefore menit',
            body: 'Waktu ${target.name} (${target.arabicName}) akan masuk pukul ${target.start}. Siapkan diri.',
            scheduledTime: beforeStart,
            payload: 'prayer_start_${target.name}',
          ),
        );
      }

      if (target.end != null) {
        final endTime = _parseEndTime(target.end!, startTime);
        final beforeEnd = endTime.subtract(Duration(minutes: minutesBefore));
        if (beforeEnd.isAfter(now)) {
          requests.add(
            ScheduledAlarmRequest(
              id: _getAlarmIdForName(target.name, 1, isTomorrow: isTomorrow),
              title: '⚠️ Waktu ${target.name} hampir habis!',
              body: 'Waktu ${target.name} (${target.arabicName}) akan berakhir pukul ${target.end}. Segera sholat!',
              scheduledTime: beforeEnd,
              payload: 'prayer_end_${target.name}',
            ),
          );
        }
      }
    }

    return requests;
  }

  static List<NativePrayerAlarm> buildNativePrayerAlarms({
    required PrayerTimes prayerTimes,
    required Map<String, AlarmMode> modes,
    required DateTime now,
    bool isTomorrow = false,
  }) {
    final requests = <NativePrayerAlarm>[];
    final baseDate = isTomorrow ? now.add(const Duration(days: 1)) : now;

    final targets = [
      ...prayerTimes.allPrayers.map((p) => _AlarmTargetInfo(
            name: p.name,
            arabicName: p.arabicName,
            iconEmoji: p.iconEmoji,
            start: p.start,
            end: p.end,
          )),
      ...prayerTimes.relatedTimes.map((r) => _AlarmTargetInfo(
            name: r.name,
            arabicName: r.name, // atau deskripsi
            iconEmoji: r.iconEmoji,
            start: r.time,
            end: null,
          )),
    ];

    for (final target in targets) {
      final mode = modes[target.name] ?? AlarmMode.off;
      if (mode != AlarmMode.alarm) continue; // Native alarm hanya jika mode = alarm

      final startTime = _parseTime(target.start, baseDate: baseDate);
      if (!startTime.isAfter(now)) continue;

      requests.add(
        NativePrayerAlarm(
          id: _getAlarmIdForName(target.name, 2, isTomorrow: isTomorrow) + 1000,
          prayerName: target.name,
          arabicName: target.arabicName,
          scheduledTime: startTime,
          timeLabel: target.start,
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
