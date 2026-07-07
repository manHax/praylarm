import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlarmSoundSelection {
  final String mode;
  final String? uri;
  final String label;

  const AlarmSoundSelection({
    required this.mode,
    required this.label,
    this.uri,
  });

  bool get isCustom =>
      mode == AlarmSoundService.customMode &&
      uri != null &&
      uri!.trim().isNotEmpty;
}

class AlarmSoundService {
  static const String defaultMode = 'default';
  static const String customMode = 'custom';
  static const String defaultLabel = 'Nada alarm Android default';

  static const _modeKey = 'alarm_sound_mode';
  static const _uriKey = 'alarm_sound_uri';
  static const _labelKey = 'alarm_sound_label';
  static const _channel = MethodChannel('prayer_alarm_app/alarm_sound');

  static const defaultSelection = AlarmSoundSelection(
    mode: defaultMode,
    label: defaultLabel,
  );

  static Future<AlarmSoundSelection> loadSelection() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_modeKey) ?? defaultMode;
    final uri = prefs.getString(_uriKey);
    final label = prefs.getString(_labelKey);

    if (mode == customMode && uri != null && uri.trim().isNotEmpty) {
      return AlarmSoundSelection(
        mode: customMode,
        uri: uri,
        label: (label == null || label.trim().isEmpty)
            ? 'File audio kustom'
            : label,
      );
    }

    return defaultSelection;
  }

  static Future<void> saveSelection(AlarmSoundSelection selection) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, selection.mode);

    if (selection.isCustom) {
      await prefs.setString(_uriKey, selection.uri!);
      await prefs.setString(_labelKey, selection.label);
      return;
    }

    await prefs.remove(_uriKey);
    await prefs.remove(_labelKey);
  }

  static Future<AlarmSoundSelection?> pickCustomAlarmSound() async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'pickAlarmSound',
    );
    if (result == null) return null;

    final uri = (result['uri'] as String?)?.trim();
    if (uri == null || uri.isEmpty) return null;

    final label = (result['label'] as String?)?.trim();
    return AlarmSoundSelection(
      mode: customMode,
      uri: uri,
      label: (label == null || label.isEmpty) ? 'File audio kustom' : label,
    );
  }
}
