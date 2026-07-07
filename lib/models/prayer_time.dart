// lib/models/prayer_time.dart

class PrayerTimes {
  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;
  final String midnight;
  final String date;
  final double latitude;
  final double longitude;
  final String timezone;

  const PrayerTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.midnight,
    required this.date,
    required this.latitude,
    required this.longitude,
    required this.timezone,
  });

  factory PrayerTimes.fromJson(Map<String, dynamic> json) {
    final timings = json['data']['timings'] as Map<String, dynamic>;
    final meta = json['data']['meta'] as Map<String, dynamic>;
    final date = json['data']['date']['readable'] as String;

    return PrayerTimes(
      fajr: timings['Fajr'] as String,
      sunrise: timings['Sunrise'] as String,
      dhuhr: timings['Dhuhr'] as String,
      asr: timings['Asr'] as String,
      maghrib: timings['Maghrib'] as String,
      isha: timings['Isha'] as String,
      midnight: timings['Midnight'] as String,
      date: date,
      latitude: (meta['latitude'] as num).toDouble(),
      longitude: (meta['longitude'] as num).toDouble(),
      timezone: meta['timezone'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'fajr': fajr,
        'sunrise': sunrise,
        'dhuhr': dhuhr,
        'asr': asr,
        'maghrib': maghrib,
        'isha': isha,
        'midnight': midnight,
        'date': date,
        'latitude': latitude,
        'longitude': longitude,
        'timezone': timezone,
      };

  String get inferredLocationName {
    final parts = timezone.split('/');
    if (parts.isEmpty) return 'Lokasi tidak diketahui';

    final cityPart = parts.last.replaceAll('_', ' ');
    return cityPart.isEmpty ? 'Lokasi tidak diketahui' : cityPart;
  }

  String get coordinateLabel =>
      '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';

  /// Mengembalikan list [nama, waktu_mulai, waktu_akhir] untuk semua sholat
  List<PrayerEntry> get allPrayers => [
        PrayerEntry(name: 'Fajr', start: fajr, end: sunrise),
        PrayerEntry(name: 'Dhuhr', start: dhuhr, end: asr),
        PrayerEntry(name: 'Asr', start: asr, end: maghrib),
        PrayerEntry(name: 'Maghrib', start: maghrib, end: isha),
        PrayerEntry(name: 'Isha', start: isha, end: midnight),
      ];

  List<RelatedTimeEntry> get relatedTimes {
    final fajrTime = _parseTime(fajr);
    final sunriseTime = _parseTime(sunrise);
    final ishaTime = _parseTime(isha);
    final midnightTime = _parseEndTime(midnight, ishaTime);
    final maghribTime = _parseTime(maghrib);
    final nextFajrTime = _parseTime(fajr).add(const Duration(days: 1));

    final nightDuration = nextFajrTime.difference(maghribTime);
    final lastThirdStart =
        maghribTime.add(Duration(minutes: (nightDuration.inMinutes * 2) ~/ 3));

    return [
      RelatedTimeEntry(
        name: 'Imsak',
        time: _formatTime(fajrTime.subtract(const Duration(minutes: 10))),
        description: 'Batas aman sahur',
        iconEmoji: '🥣',
      ),
      RelatedTimeEntry(
        name: 'Syuruq',
        time: sunrise,
        description: 'Matahari terbit',
        iconEmoji: '🌄',
      ),
      RelatedTimeEntry(
        name: 'Dhuha',
        time: _formatTime(sunriseTime.add(const Duration(minutes: 15))),
        description: 'Awal waktu dhuha',
        iconEmoji: '🌤️',
      ),
      RelatedTimeEntry(
        name: 'Tengah Malam',
        time: _formatTime(midnightTime),
        description: 'Pertengahan malam syar\'i',
        iconEmoji: '🌙',
      ),
      RelatedTimeEntry(
        name: 'Tahajud Utama',
        time: _formatTime(lastThirdStart),
        description: 'Awal sepertiga malam akhir',
        iconEmoji: '✨',
      ),
    ];
  }

  DateTime _parseTime(String timeStr, {DateTime? baseDate}) {
    final clean = timeStr.split(' ').first.trim();
    final parts = clean.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final now = baseDate ?? DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  DateTime _parseEndTime(String timeStr, DateTime startTime) {
    var endTime = _parseTime(timeStr, baseDate: startTime);
    if (!endTime.isAfter(startTime)) {
      endTime = endTime.add(const Duration(days: 1));
    }
    return endTime;
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class PrayerEntry {
  final String name;
  final String start; // format "HH:mm"
  final String end;   // format "HH:mm"

  const PrayerEntry({
    required this.name,
    required this.start,
    required this.end,
  });

  String get arabicName {
    const map = {
      'Fajr': 'الفجر',
      'Dhuhr': 'الظهر',
      'Asr': 'العصر',
      'Maghrib': 'المغرب',
      'Isha': 'العشاء',
    };
    return map[name] ?? name;
  }

  String get iconEmoji {
    const map = {
      'Fajr': '🌙',
      'Dhuhr': '☀️',
      'Asr': '🌤️',
      'Maghrib': '🌅',
      'Isha': '🌃',
    };
    return map[name] ?? '🕌';
  }
}

class RelatedTimeEntry {
  final String name;
  final String time;
  final String description;
  final String iconEmoji;

  const RelatedTimeEntry({
    required this.name,
    required this.time,
    required this.description,
    required this.iconEmoji,
  });
}
