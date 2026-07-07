import 'package:flutter/services.dart';

class DeviceTimezoneService {
  static const MethodChannel _channel =
      MethodChannel('prayer_alarm_app/timezone');

  static Future<String> getLocalTimezone() async {
    try {
      final timezone = await _channel.invokeMethod<String>('getLocalTimezone');
      if (timezone != null && timezone.isNotEmpty) {
        return timezone;
      }
    } catch (_) {
      // Fallback handled below.
    }

    return _fallbackTimezone();
  }

  static String _fallbackTimezone() {
    switch (DateTime.now().timeZoneName) {
      case 'WIB':
        return 'Asia/Jakarta';
      case 'WITA':
        return 'Asia/Makassar';
      case 'WIT':
        return 'Asia/Jayapura';
      default:
        return 'UTC';
    }
  }
}
