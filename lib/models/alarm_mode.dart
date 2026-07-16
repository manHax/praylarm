// lib/models/alarm_mode.dart

enum AlarmMode {
  off,
  push,
  alarm,
}

extension AlarmModeExt on AlarmMode {
  String get label {
    switch (this) {
      case AlarmMode.off:
        return 'Mati';
      case AlarmMode.push:
        return 'Push Notif';
      case AlarmMode.alarm:
        return 'Alarm Penuh';
    }
  }

  static AlarmMode fromString(String value) {
    switch (value) {
      case 'off':
        return AlarmMode.off;
      case 'push':
        return AlarmMode.push;
      case 'alarm':
        return AlarmMode.alarm;
      default:
        return AlarmMode.alarm; // default is alarm for prayers, maybe off for others?
    }
  }

  String get stringValue {
    switch (this) {
      case AlarmMode.off:
        return 'off';
      case AlarmMode.push:
        return 'push';
      case AlarmMode.alarm:
        return 'alarm';
    }
  }
}
