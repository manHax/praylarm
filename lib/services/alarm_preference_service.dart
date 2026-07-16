// lib/services/alarm_preference_service.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'package:prayer_alarm_app/models/alarm_mode.dart';

class AlarmPreferenceService {
  static const _prefix = 'alarm_mode_';

  // Default untuk sholat wajib: alarm penuh
  static AlarmMode _getDefaultModeFor(String name) {
    const prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    if (prayers.contains(name)) {
      return AlarmMode.alarm;
    }
    // Default untuk waktu lainnya (Imsak, Syuruq, dll): mati
    return AlarmMode.off;
  }

  static Future<AlarmMode> getMode(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('$_prefix$name');
    if (value == null) {
      return _getDefaultModeFor(name);
    }
    return AlarmModeExt.fromString(value);
  }

  static Future<void> setMode(String name, AlarmMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$name', mode.stringValue);
  }

  static Future<Map<String, AlarmMode>> getAllModes(List<String> names) async {
    final map = <String, AlarmMode>{};
    for (final name in names) {
      map[name] = await getMode(name);
    }
    return map;
  }
}
