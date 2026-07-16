// lib/main.dart

import 'dart:async';
import 'dart:io';
import 'package:prayer_alarm_app/services/theme_service.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:intl/date_symbol_data_local.dart';
import 'package:prayer_alarm_app/services/background_service.dart';
import 'package:prayer_alarm_app/services/alarm_service.dart';
import 'package:prayer_alarm_app/services/location_refresh_service.dart';
import 'package:prayer_alarm_app/services/notification_service.dart';
import 'package:prayer_alarm_app/ui/home_screen.dart';

const _alarmSelfTestOnStartup =
    bool.fromEnvironment('ALARM_SELF_TEST', defaultValue: false);
const _nativeAlarmSelfTestOnStartup =
    bool.fromEnvironment('NATIVE_ALARM_SELF_TEST', defaultValue: false);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientasi ke portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Init timezone data
  tz_data.initializeTimeZones();

  // Init locale Indonesia
  await initializeDateFormatting('id_ID', null);

  runApp(const PrayerAlarmApp());
  unawaited(_bootstrapAppServices());
}

Future<void> _bootstrapAppServices() async {
  try {
    await NotificationService.initialize();
    await AlarmService.initialize();

    // Jangan blok first paint dengan dialog permission.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await NotificationService.requestPermission();

    if (_alarmSelfTestOnStartup) {
      final scheduledAt = await AlarmService.runNotificationSelfTest();
      final pendingCount = await NotificationService.pendingNotificationCount();
      debugPrint(
        'ALARM_SELF_TEST scheduledAt=$scheduledAt pendingCount=$pendingCount',
      );
    }

    if (_nativeAlarmSelfTestOnStartup) {
      final scheduledAt = await AlarmService.runNativeAlarmSelfTest();
      debugPrint('NATIVE_ALARM_SELF_TEST scheduledAt=$scheduledAt');
    }

    await LocationRefreshService.initialize();

    // Foreground background service dimatikan di Android karena crash pada
    // beberapa perangkat OEM saat startForeground. Alarm inti tetap berjalan.
    if (!Platform.isAndroid) {
      await BackgroundServiceManager.initialize();
    }
  } catch (error, stackTrace) {
    debugPrint('App bootstrap failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

final themeService = ThemeService();

class PrayerAlarmApp extends StatelessWidget {
  const PrayerAlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        return MaterialApp(
          title: 'Prayer Alarm',
          debugShowCheckedModeBanner: false,
          themeMode: themeService.themeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFD4AF37),
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFD4AF37),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          home: const HomeScreen(),
        );
      },
    );
  }
}
