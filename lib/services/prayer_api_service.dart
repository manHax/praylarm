// lib/services/prayer_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prayer_alarm_app/models/prayer_time.dart';

class PrayerApiService {
  static const _baseUrl = 'https://api.aladhan.com/v1';
  static const _cacheKey = 'cached_prayer_times_v2';
  static const _cacheDateKey = 'cached_prayer_date_v2';
  static const _cacheMethodKey = 'cached_prayer_method_v2';
  static const _calculationMethodKey = 'calculation_method';
  static const defaultCalculationMethod = '20';

  static String normalizeCalculationMethod(String? rawMethod) {
    switch (rawMethod) {
      // Migrasi dari mapping lama yang keliru di app.
      case '11':
        return '20';
      case '2':
        return '3';
      case '3':
        return '5';
      case '1':
      case '4':
      case '20':
      case 'muhammadiyah':
        return rawMethod!;
      default:
        return defaultCalculationMethod;
    }
  }

  static int _resolveApiMethod(String method) {
    switch (method) {
      case '1':
        return 1; // Karachi
      case '3':
        return 3; // Muslim World League
      case '4':
        return 4; // Umm Al-Qura
      case '5':
        return 5; // Egyptian Authority
      case '20':
        return 20; // Kemenag RI
      case 'muhammadiyah':
        // AlAdhan tidak menyediakan metode Muhammadiyah bawaan, jadi untuk
        // sementara gunakan profil Kemenag sebagai fallback terdekat.
        return 20;
      default:
        return 20;
    }
  }

  static Future<String> _selectedCalculationMethod() async {
    final prefs = await SharedPreferences.getInstance();
    return normalizeCalculationMethod(prefs.getString(_calculationMethodKey));
  }

  /// Ambil jadwal sholat untuk hari ini berdasarkan koordinat
  static Future<PrayerTimes> getPrayerTimes({
    required double lat,
    required double lng,
    DateTime? date,
  }) async {
    final targetDate = date ?? DateTime.now();
    final selectedMethod = await _selectedCalculationMethod();
    final apiMethod = _resolveApiMethod(selectedMethod);
    final dateStr =
        '${targetDate.day.toString().padLeft(2, '0')}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.year}';

    // Cek cache (hanya cache untuk hari ini)
    final cached = await _getCached(dateStr, selectedMethod);
    if (cached != null) return cached;

    // Fetch dari API
    final url = Uri.parse(
      '$_baseUrl/timings/$dateStr'
      '?latitude=$lat'
      '&longitude=$lng'
      '&method=$apiMethod'
      '&school=0', // school=0 → Syafi'i (umum di Indonesia)
    );

    final response = await http.get(url).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Gagal mengambil jadwal sholat: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['code'] != 200) {
      throw Exception('API error: ${json['status']}');
    }

    final prayerTimes = PrayerTimes.fromJson(json);
    await _cache(prayerTimes, dateStr, selectedMethod);
    return prayerTimes;
  }

  /// Ambil jadwal sholat besok (untuk schedule alarm malam hari)
  static Future<PrayerTimes> getTomorrowPrayerTimes({
    required double lat,
    required double lng,
  }) async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return getPrayerTimes(lat: lat, lng: lng, date: tomorrow);
  }

  static Future<PrayerTimes?> _getCached(
    String dateStr,
    String selectedMethod,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedDate = prefs.getString(_cacheDateKey);
      final cachedMethod =
          normalizeCalculationMethod(prefs.getString(_cacheMethodKey));
      if (cachedDate != dateStr) return null;
      if (cachedMethod != selectedMethod) return null;

      final cachedJson = prefs.getString(_cacheKey);
      if (cachedJson == null) return null;

      final map = jsonDecode(cachedJson) as Map<String, dynamic>;
      return PrayerTimes.fromJson({'data': _reconstructApiFormat(map)});
    } catch (_) {
      return null;
    }
  }

  static Future<void> _cache(
    PrayerTimes pt,
    String dateStr,
    String selectedMethod,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheDateKey, dateStr);
    await prefs.setString(_cacheMethodKey, selectedMethod);
    await prefs.setString(_cacheKey, jsonEncode(pt.toJson()));
  }

  static Map<String, dynamic> _reconstructApiFormat(Map<String, dynamic> map) {
    return {
      'timings': {
        'Fajr': map['fajr'],
        'Sunrise': map['sunrise'],
        'Dhuhr': map['dhuhr'],
        'Asr': map['asr'],
        'Maghrib': map['maghrib'],
        'Isha': map['isha'],
        'Midnight': map['midnight'],
      },
      'date': {'readable': map['date']},
      'meta': {
        'latitude': map['latitude'],
        'longitude': map['longitude'],
        'timezone': map['timezone'],
      },
    };
  }
}
