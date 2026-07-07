// lib/services/location_service.dart

import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LocationSnapshot {
  final double lat;
  final double lng;
  final double altitude;
  final String area;
  final String city;
  final String country;
  final DateTime cachedAt;

  const LocationSnapshot({
    required this.lat,
    required this.lng,
    required this.altitude,
    required this.area,
    required this.city,
    required this.country,
    required this.cachedAt,
  });

  String? get primaryLabel {
    for (final value in [area, city, country]) {
      final clean = value.trim();
      if (clean.isNotEmpty) return clean;
    }
    return null;
  }

  String? get secondaryLabel {
    final parts = <String>[];
    final normalizedArea = area.trim().toLowerCase();
    final normalizedCity = city.trim().toLowerCase();

    if (city.trim().isNotEmpty &&
        normalizedCity != normalizedArea) {
      parts.add(city.trim());
    }
    if (country.trim().isNotEmpty) {
      parts.add(country.trim());
    }
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }
}

class LocationService {
  static const _latKey = 'cached_lat';
  static const _lngKey = 'cached_lng';
  static const _altitudeKey = 'cached_altitude';
  static const _areaKey = 'cached_area';
  static const _cityKey = 'cached_city';
  static const _countryKey = 'cached_country';
  static const _timeKey = 'cached_location_time';
  static const _cacheHours = 6; // cache lokasi 6 jam

  /// Ambil lokasi terkini, dengan fallback ke cache jika GPS gagal
  static Future<LocationSnapshot> getCurrentLocation({
    bool ignoreCache = false,
  }) async {
    // 1. Cek cache dulu
    if (!ignoreCache) {
      final cached = await _getCachedLocation();
      if (cached != null) return cached;
    }

    // 2. Cek & minta permission
    final permission = await ensurePermission();
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Izin lokasi ditolak permanen. Buka Settings untuk mengaktifkan.');
    }
    if (permission == LocationPermission.denied) {
      throw Exception('Izin lokasi belum diberikan.');
    }

    // 3. Ambil posisi
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium, // hemat baterai
      timeLimit: const Duration(seconds: 15),
    );

    // 4. Simpan ke cache
    return _cacheLocation(position);
  }

  static Future<LocationPermission> ensurePermission({
    bool requestIfNeeded = true,
  }) async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestIfNeeded) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  /// Ambil lokasi tanpa menampilkan dialog permission (untuk background service)
  static Future<LocationSnapshot?> getLocationSilently() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return await _getCachedLocation();
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
      return _cacheLocation(position);
    } catch (_) {
      return await _getCachedLocation();
    }
  }

  static Future<LocationSnapshot?> _getCachedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_latKey);
    final lng = prefs.getDouble(_lngKey);
    final altitude = prefs.getDouble(_altitudeKey) ?? 0;
    final area = prefs.getString(_areaKey) ?? '';
    final city = prefs.getString(_cityKey) ?? '';
    final country = prefs.getString(_countryKey) ?? '';
    final time = prefs.getInt(_timeKey);

    if (lat == null || lng == null || time == null) return null;

    final cached = DateTime.fromMillisecondsSinceEpoch(time);
    final diff = DateTime.now().difference(cached);
    if (diff.inHours >= _cacheHours) return null;

    return LocationSnapshot(
      lat: lat,
      lng: lng,
      altitude: altitude,
      area: area,
      city: city,
      country: country,
      cachedAt: cached,
    );
  }

  static Future<LocationSnapshot> _cacheLocation(Position position) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final altitude =
        position.altitude.isFinite ? position.altitude : 0.0;
    final place = await _reverseGeocode(
      lat: position.latitude,
      lng: position.longitude,
    );

    await prefs.setDouble(_latKey, position.latitude);
    await prefs.setDouble(_lngKey, position.longitude);
    await prefs.setDouble(_altitudeKey, altitude);
    await prefs.setString(_areaKey, place.area);
    await prefs.setString(_cityKey, place.city);
    await prefs.setString(_countryKey, place.country);
    await prefs.setInt(_timeKey, now.millisecondsSinceEpoch);

    return LocationSnapshot(
      lat: position.latitude,
      lng: position.longitude,
      altitude: altitude,
      area: place.area,
      city: place.city,
      country: place.country,
      cachedAt: now,
    );
  }

  static Future<_ResolvedPlace> _reverseGeocode({
    required double lat,
    required double lng,
  }) async {
    try {
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/reverse',
        {
          'format': 'jsonv2',
          'lat': lat.toString(),
          'lon': lng.toString(),
          'zoom': '14',
          'addressdetails': '1',
        },
      );
      final response = await http.get(
        uri,
        headers: const {
          'User-Agent': 'praylarm/1.0 (reverse geocoding)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return const _ResolvedPlace.empty();
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final address = (json['address'] as Map<String, dynamic>?) ?? const {};

      return _ResolvedPlace(
        area: _firstNonEmpty(address, const [
          'suburb',
          'neighbourhood',
          'quarter',
          'city_district',
          'district',
          'village',
          'hamlet',
        ]),
        city: _firstNonEmpty(address, const [
          'city',
          'town',
          'municipality',
          'county',
          'state_district',
          'state',
        ]),
        country: _firstNonEmpty(address, const [
          'country',
        ]),
      );
    } catch (_) {
      return const _ResolvedPlace.empty();
    }
  }

  static String _firstNonEmpty(
    Map<String, dynamic> source,
    List<String> keys,
  ) {
    for (final key in keys) {
      final raw = source[key];
      if (raw is! String) continue;
      final value = raw.trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  /// Hapus cache lokasi (paksa refresh)
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_latKey);
    await prefs.remove(_lngKey);
    await prefs.remove(_altitudeKey);
    await prefs.remove(_areaKey);
    await prefs.remove(_cityKey);
    await prefs.remove(_countryKey);
    await prefs.remove(_timeKey);
  }

  static Future<DateTime?> getLastCachedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final time = prefs.getInt(_timeKey);
    if (time == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(time);
  }
}

class _ResolvedPlace {
  final String area;
  final String city;
  final String country;

  const _ResolvedPlace({
    required this.area,
    required this.city,
    required this.country,
  });

  const _ResolvedPlace.empty()
      : area = '',
        city = '',
        country = '';
}
