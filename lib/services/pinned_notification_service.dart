import 'package:shared_preferences/shared_preferences.dart';
import 'package:prayer_alarm_app/services/notification_service.dart';
import 'package:prayer_alarm_app/models/prayer_time.dart';

class PinnedNotificationService {
  static const _key = 'pinned_notification_enabled';

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
    if (!enabled) {
      await NotificationService.cancelPinnedNotification();
    }
  }

  static Future<void> updatePinnedNotification({
    required PrayerTimes pt,
    required String locationStatus,
  }) async {
    final enabled = await isEnabled();
    if (!enabled) {
      await NotificationService.cancelPinnedNotification();
      return;
    }

    final title = '📍 $locationStatus';
    final body = '🌙 ${_format(pt.fajr)} | ☀️ ${_format(pt.dhuhr)} | 🌤️ ${_format(pt.asr)}\n🌅 ${_format(pt.maghrib)} | 🌃 ${_format(pt.isha)}';

    await NotificationService.showPinnedNotification(
      title: title,
      body: body,
    );
  }

  static String _format(String time) {
    if (time.length >= 5) {
      return time.substring(0, 5);
    }
    return time;
  }
}
