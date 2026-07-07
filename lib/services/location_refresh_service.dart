import 'dart:io';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alarm_service.dart';
import 'home_widget_service.dart';
import 'location_service.dart';
import 'prayer_api_service.dart';

@pragma('vm:entry-point')
Future<void> locationRefreshAlarmCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await LocationRefreshService.handleScheduledRefresh();
}

class LocationRefreshService {
  static const modeManual = 'manual';
  static const modeHourly = 'hourly';
  static const modeEvery3Hours = 'every_3_hours';
  static const modeDailyTime = 'daily_time';

  static const _refreshModeKey = 'location_refresh_mode';
  static const _dailyHourKey = 'location_refresh_daily_hour';
  static const _dailyMinuteKey = 'location_refresh_daily_minute';
  static const _lastRefreshKey = 'location_refresh_last_run';

  static const defaultRefreshMode = modeManual;
  static const defaultDailyHour = 0;
  static const defaultDailyMinute = 0;

  static const _intervalAlarmId = 70001;
  static const _dailyAlarmId = 70002;

  static Future<void> initialize() async {
    if (!Platform.isAndroid) return;
    await AndroidAlarmManager.initialize();
    await scheduleFromSettings();
  }

  static Future<void> scheduleFromSettings() async {
    if (!Platform.isAndroid) return;

    await cancelAll();

    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_refreshModeKey) ?? defaultRefreshMode;

    switch (mode) {
      case modeHourly:
        await AndroidAlarmManager.periodic(
          const Duration(hours: 1),
          _intervalAlarmId,
          locationRefreshAlarmCallback,
          wakeup: true,
          allowWhileIdle: true,
          rescheduleOnReboot: true,
        );
        break;
      case modeEvery3Hours:
        await AndroidAlarmManager.periodic(
          const Duration(hours: 3),
          _intervalAlarmId,
          locationRefreshAlarmCallback,
          wakeup: true,
          allowWhileIdle: true,
          rescheduleOnReboot: true,
        );
        break;
      case modeDailyTime:
        await _scheduleNextDailyRefresh();
        break;
      case modeManual:
      default:
        break;
    }
  }

  static Future<void> cancelAll() async {
    if (!Platform.isAndroid) return;
    await AndroidAlarmManager.cancel(_intervalAlarmId);
    await AndroidAlarmManager.cancel(_dailyAlarmId);
  }

  static Future<void> saveSettings({
    required String mode,
    required int dailyHour,
    required int dailyMinute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_refreshModeKey, mode);
    await prefs.setInt(_dailyHourKey, dailyHour);
    await prefs.setInt(_dailyMinuteKey, dailyMinute);
  }

  static Future<String> getRefreshMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshModeKey) ?? defaultRefreshMode;
  }

  static Future<({int hour, int minute})> getDailyRefreshTime() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      hour: prefs.getInt(_dailyHourKey) ?? defaultDailyHour,
      minute: prefs.getInt(_dailyMinuteKey) ?? defaultDailyMinute,
    );
  }

  static Future<DateTime?> getLastRefreshAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt(_lastRefreshKey);
    if (raw == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(raw);
  }

  static Future<void> handleScheduledRefresh() async {
    await refreshNow();

    final mode = await getRefreshMode();
    if (mode == modeDailyTime) {
      await _scheduleNextDailyRefresh();
    }
  }

  static Future<bool> refreshNow() async {
    final location = await LocationService.getLocationSilently();
    if (location == null) return false;

    final prayerTimes = await PrayerApiService.getPrayerTimes(
      lat: location.lat,
      lng: location.lng,
    );

    await AlarmService.scheduleAllAlarms(prayerTimes);
    await HomeWidgetService.update(prayerTimes);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastRefreshKey, DateTime.now().millisecondsSinceEpoch);
    return true;
  }

  static Future<void> _scheduleNextDailyRefresh() async {
    final dailyTime = await getDailyRefreshTime();
    final nextRun = _nextDailyRun(
      hour: dailyTime.hour,
      minute: dailyTime.minute,
    );

    await AndroidAlarmManager.oneShotAt(
      nextRun,
      _dailyAlarmId,
      locationRefreshAlarmCallback,
      exact: true,
      wakeup: true,
      allowWhileIdle: true,
      rescheduleOnReboot: true,
    );
  }

  static DateTime _nextDailyRun({
    required int hour,
    required int minute,
  }) {
    final now = DateTime.now();
    var runAt = DateTime(now.year, now.month, now.day, hour, minute);
    if (!runAt.isAfter(now)) {
      runAt = runAt.add(const Duration(days: 1));
    }
    return runAt;
  }

  static Future<bool> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.scheduleExactAlarm.request();
    return status.isGranted;
  }
}
