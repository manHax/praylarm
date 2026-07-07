import 'package:flutter/services.dart';

class NativePrayerAlarm {
  final int id;
  final String prayerName;
  final String arabicName;
  final DateTime scheduledTime;
  final String timeLabel;

  const NativePrayerAlarm({
    required this.id,
    required this.prayerName,
    required this.arabicName,
    required this.scheduledTime,
    required this.timeLabel,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'prayerName': prayerName,
      'arabicName': arabicName,
      'scheduledTimeMillis': scheduledTime.millisecondsSinceEpoch,
      'timeLabel': timeLabel,
    };
  }
}

class NativeAlarmService {
  static const _channel = MethodChannel('prayer_alarm_app/native_alarm');

  static Future<int> schedulePrayerAlarms(
    List<NativePrayerAlarm> alarms,
  ) async {
    final count = await _channel.invokeMethod<int>(
      'schedulePrayerAlarms',
      {
        'alarms': alarms.map((alarm) => alarm.toMap()).toList(),
      },
    );
    return count ?? 0;
  }

  static Future<void> cancelAllPrayerAlarms() async {
    await _channel.invokeMethod<void>('cancelAllPrayerAlarms');
  }

  static Future<DateTime?> scheduleSelfTestAlarm() async {
    final millis = await _channel.invokeMethod<int>('scheduleSelfTestAlarm');
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }
}
