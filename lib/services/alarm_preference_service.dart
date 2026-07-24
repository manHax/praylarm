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

  static const _minutesPrefix = 'alarm_minutes_';
  
  static Future<int> getMinutesBefore(String name) async {
    final prefs = await SharedPreferences.getInstance();
    // Gunakan 10 menit sebagai default
    return prefs.getInt('$_minutesPrefix$name') ?? 10;
  }

  static Future<void> setMinutesBefore(String name, int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_minutesPrefix$name', minutes);
  }

  static Future<Map<String, int>> getAllMinutesBefore(List<String> names) async {
    final map = <String, int>{};
    for (final name in names) {
      map[name] = await getMinutesBefore(name);
    }
    return map;
  }

  static const _modeBeforePrefix = 'alarm_mode_before_';
  
  static Future<AlarmMode> getModeBefore(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('$_modeBeforePrefix$name');
    if (value == null) {
      // Default: ikuti mode default
      return _getDefaultModeFor(name);
    }
    return AlarmModeExt.fromString(value);
  }

  static Future<void> setModeBefore(String name, AlarmMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_modeBeforePrefix$name', mode.stringValue);
  }

  static Future<Map<String, AlarmMode>> getAllModeBefore(List<String> names) async {
    final map = <String, AlarmMode>{};
    for (final name in names) {
      map[name] = await getModeBefore(name);
    }
    return map;
  }

  static const _modeAfterPrefix = 'alarm_mode_after_';
  
  static Future<AlarmMode> getModeAfter(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('$_modeAfterPrefix$name');
    if (value == null) {
      // Default: ikuti mode default
      return _getDefaultModeFor(name);
    }
    return AlarmModeExt.fromString(value);
  }

  static Future<void> setModeAfter(String name, AlarmMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_modeAfterPrefix$name', mode.stringValue);
  }

  static Future<Map<String, AlarmMode>> getAllModeAfter(List<String> names) async {
    final map = <String, AlarmMode>{};
    for (final name in names) {
      map[name] = await getModeAfter(name);
    }
    return map;
  }
}
