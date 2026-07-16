import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_alarm_app/models/prayer_time.dart';
import 'package:prayer_alarm_app/services/alarm_service.dart';
import 'package:prayer_alarm_app/models/alarm_mode.dart';

void main() {
  group('AlarmService.buildScheduleRequests', () {
    const prayerTimes = PrayerTimes(
      fajr: '04:30',
      sunrise: '05:45',
      dhuhr: '12:00',
      asr: '15:15',
      maghrib: '18:00',
      isha: '19:15',
      midnight: '00:00',
      date: '07 Jul 2026',
      latitude: -7.2575,
      longitude: 112.7521,
      timezone: 'Asia/Jakarta',
    );

    final testModes = {
      'Fajr': AlarmMode.alarm,
      'Dhuhr': AlarmMode.alarm,
      'Asr': AlarmMode.alarm,
      'Maghrib': AlarmMode.alarm,
      'Isha': AlarmMode.alarm,
      'Imsak': AlarmMode.off,
      'Syuruq': AlarmMode.off,
      'Dhuha': AlarmMode.off,
      'Tengah Malam': AlarmMode.off,
      'Tahajud Utama': AlarmMode.off,
    };

    test('creates all future start/end reminders before fajr', () {
      final now = DateTime(2026, 7, 7, 3, 0);

      final requests = AlarmService.buildScheduleRequests(
        prayerTimes: prayerTimes,
        modes: testModes,
        now: now,
        minutesBefore: 10,
      );

      expect(requests, hasLength(10));
      expect(requests.first.title, '🌙 Fajr dalam 10 menit');
      expect(
        requests.first.scheduledTime,
        DateTime(2026, 7, 7, 4, 20),
      );
      expect(
        requests.last.scheduledTime,
        DateTime(2026, 7, 7, 23, 50),
      );
    });

    test('skips past reminders and keeps future ones midday', () {
      final now = DateTime(2026, 7, 7, 12, 5);

      final requests = AlarmService.buildScheduleRequests(
        prayerTimes: prayerTimes,
        modes: testModes,
        now: now,
        minutesBefore: 10,
      );

      expect(
        requests.map((request) => request.payload),
        [
          'prayer_end_Dhuhr',
          'prayer_start_Asr',
          'prayer_end_Asr',
          'prayer_start_Maghrib',
          'prayer_end_Maghrib',
          'prayer_start_Isha',
          'prayer_end_Isha',
        ],
      );
      expect(
        requests.first.scheduledTime,
        DateTime(2026, 7, 7, 15, 5),
      );
      expect(
        requests.last.scheduledTime,
        DateTime(2026, 7, 7, 23, 50),
      );
    });
  });
}
