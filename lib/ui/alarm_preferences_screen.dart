// lib/ui/alarm_preferences_screen.dart

import 'package:flutter/material.dart';
import 'package:prayer_alarm_app/theme/app_colors.dart';
import 'package:prayer_alarm_app/models/alarm_mode.dart';
import 'package:prayer_alarm_app/services/alarm_preference_service.dart';
import 'package:prayer_alarm_app/services/alarm_service.dart';
import 'package:prayer_alarm_app/services/location_service.dart';
import 'package:prayer_alarm_app/services/prayer_api_service.dart';
import 'package:prayer_alarm_app/theme/app_text_styles.dart';

class AlarmPreferencesScreen extends StatefulWidget {
  const AlarmPreferencesScreen({super.key});

  @override
  State<AlarmPreferencesScreen> createState() => _AlarmPreferencesScreenState();
}

class _AlarmPreferencesScreenState extends State<AlarmPreferencesScreen> {
  final _prayers = [
    {'name': 'Fajr', 'label': 'Subuh', 'icon': '🌙'},
    {'name': 'Dhuhr', 'label': 'Dzuhur', 'icon': '☀️'},
    {'name': 'Asr', 'label': 'Ashar', 'icon': '🌤️'},
    {'name': 'Maghrib', 'label': 'Maghrib', 'icon': '🌅'},
    {'name': 'Isha', 'label': 'Isya', 'icon': '🌃'},
  ];

  final _relatedTimes = [
    {'name': 'Imsak', 'label': 'Imsak', 'icon': '🥣'},
    {'name': 'Syuruq', 'label': 'Syuruq', 'icon': '🌄'},
    {'name': 'Dhuha', 'label': 'Dhuha', 'icon': '🌤️'},
    {'name': 'Tengah Malam', 'label': 'Tengah Malam', 'icon': '🌙'},
    {'name': 'Tahajud Utama', 'label': 'Tahajud', 'icon': '✨'},
  ];

  Map<String, AlarmMode> _modes = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadModes();
  }

  Future<void> _loadModes() async {
    final allNames = [
      ..._prayers.map((e) => e['name']!),
      ..._relatedTimes.map((e) => e['name']!),
    ];
    final modes = await AlarmPreferenceService.getAllModes(allNames);
    setState(() {
      _modes = modes;
      _isLoading = false;
    });
  }

  Future<void> _updateMode(String name, AlarmMode mode) async {
    setState(() {
      _modes[name] = mode;
    });
    await AlarmPreferenceService.setMode(name, mode);
    
    // Reschedule alarms after modifying
    final location = await LocationService.getLocationSilently();
    if (location != null) {
      try {
        final pt = await PrayerApiService.getPrayerTimes(
          lat: location.lat, 
          lng: location.lng
        );
        await AlarmService.scheduleAllAlarms(pt);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: context.colors.appBarBackground,
        title: Text(
          'Konfigurasi Waktu',
          style: AppTextStyles.nunito(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: context.colors.textPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.paddingOf(context).bottom),
              children: [
                _sectionTitle('Sholat Wajib'),
                _buildCard(
                  _prayers.map((p) => _buildRow(p)).toList(),
                ),
                const SizedBox(height: 24),
                _sectionTitle('Waktu Terkait'),
                _buildCard(
                  _relatedTimes.map((r) => _buildRow(r)).toList(),
                ),
              ],
            ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.nunito(
          color: context.colors.primaryAccent,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildRow(Map<String, String> item) {
    final name = item['name']!;
    final mode = _modes[name] ?? AlarmMode.off;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(item['icon']!, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item['label']!,
              style: AppTextStyles.nunito(color: context.colors.textPrimary, fontSize: 16),
            ),
          ),
          DropdownButton<AlarmMode>(
            value: mode,
            dropdownColor: context.colors.appBarBackground,
            icon: Icon(Icons.arrow_drop_down, color: context.colors.textSecondary),
            underline: const SizedBox(),
            items: AlarmMode.values.map((m) {
              return DropdownMenuItem<AlarmMode>(
                value: m,
                child: Text(
                  m.label,
                  style: AppTextStyles.nunito(
                    color: m == AlarmMode.off ? context.colors.textSecondary : context.colors.textPrimary,
                    fontSize: 14,
                  ),
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) _updateMode(name, val);
            },
          ),
        ],
      ),
    );
  }
}
