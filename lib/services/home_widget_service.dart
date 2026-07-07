// lib/services/home_widget_service.dart
//
// Update homescreen widget dengan jadwal sholat terkini

import 'package:home_widget/home_widget.dart';
import 'package:prayer_alarm_app/models/prayer_time.dart';
import 'alarm_service.dart';

class HomeWidgetService {
  static const _appGroupId = 'group.com.yourapp.prayeralarm';
  static const _widgetName = 'PrayerTimesWidget';

  static Future<void> update(PrayerTimes prayerTimes) async {
    try {
      await HomeWidget.setAppGroupId(_appGroupId);

      final next = AlarmService.getNextPrayer(prayerTimes);
      final duration = AlarmService.getTimeUntilNextPrayer(prayerTimes);

      // Data yang dikirim ke widget
      await Future.wait([
        HomeWidget.saveWidgetData('fajr', prayerTimes.fajr),
        HomeWidget.saveWidgetData('dhuhr', prayerTimes.dhuhr),
        HomeWidget.saveWidgetData('asr', prayerTimes.asr),
        HomeWidget.saveWidgetData('maghrib', prayerTimes.maghrib),
        HomeWidget.saveWidgetData('isha', prayerTimes.isha),
        HomeWidget.saveWidgetData('next_prayer', next?.name ?? ''),
        HomeWidget.saveWidgetData('next_prayer_time', next?.start ?? ''),
        HomeWidget.saveWidgetData(
          'countdown',
          duration != null
              ? '${duration.inHours}j ${duration.inMinutes % 60}m'
              : '',
        ),
        HomeWidget.saveWidgetData('date', prayerTimes.date),
        HomeWidget.saveWidgetData(
            'last_update',
            DateTime.now().toIso8601String()),
      ]);

      // Trigger update widget di homescreen
      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: _widgetName,
        iOSName: _widgetName,
      );
    } catch (_) {
      // Widget mungkin belum dipasang, tidak apa-apa
    }
  }
}
