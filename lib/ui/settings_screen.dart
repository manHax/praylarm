// lib/ui/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prayer_alarm_app/services/alarm_sound_service.dart';
import 'package:prayer_alarm_app/services/location_service.dart';
import 'package:prayer_alarm_app/services/alarm_service.dart';
import 'package:prayer_alarm_app/services/location_refresh_service.dart';
import 'package:prayer_alarm_app/services/notification_service.dart';
import 'package:prayer_alarm_app/services/prayer_api_service.dart';
import 'package:prayer_alarm_app/theme/app_text_styles.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _notificationsEnabled = true;
  int _minutesBefore = 10;
  String _calculationMethod = PrayerApiService.defaultCalculationMethod;
  String _alarmSoundMode = AlarmSoundService.defaultMode;
  String? _alarmSoundUri;
  String _alarmSoundLabel = AlarmSoundService.defaultLabel;
  String _locationRefreshMode = LocationRefreshService.defaultRefreshMode;
  TimeOfDay _dailyRefreshTime = const TimeOfDay(hour: 0, minute: 0);
  PermissionStatus _locationStatus = PermissionStatus.denied;
  PermissionStatus _backgroundLocationStatus = PermissionStatus.denied;
  PermissionStatus _exactAlarmStatus = PermissionStatus.granted;
  DateTime? _lastAutoRefreshAt;
  DateTime? _lastCachedLocationAt;

  final _methods = {
    '20': 'Kemenag Indonesia',
    'muhammadiyah': 'Muhammadiyah',
    '3': 'Muslim World League',
    '5': 'Egyptian Authority',
    '4': 'Umm Al-Qura (Mekkah)',
    '1': 'University of Islamic Sciences, Karachi',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final dailyRefreshTime = await LocationRefreshService.getDailyRefreshTime();
    final alarmSoundSelection = await AlarmSoundService.loadSelection();
    final locationStatus = await Permission.locationWhenInUse.status;
    final backgroundLocationStatus = await Permission.locationAlways.status;
    final exactAlarmStatus = await Permission.scheduleExactAlarm.status;
    final lastAutoRefreshAt = await LocationRefreshService.getLastRefreshAt();
    final lastCachedLocationAt = await LocationService.getLastCachedAt();

    setState(() {
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _minutesBefore = prefs.getInt('minutes_before') ?? 10;
      _calculationMethod = PrayerApiService.normalizeCalculationMethod(
        prefs.getString('calculation_method'),
      );
      _alarmSoundMode = alarmSoundSelection.mode;
      _alarmSoundUri = alarmSoundSelection.uri;
      _alarmSoundLabel = alarmSoundSelection.label;
      _locationRefreshMode =
          prefs.getString('location_refresh_mode') ??
              LocationRefreshService.defaultRefreshMode;
      _dailyRefreshTime = TimeOfDay(
        hour: dailyRefreshTime.hour,
        minute: dailyRefreshTime.minute,
      );
      _locationStatus = locationStatus;
      _backgroundLocationStatus = backgroundLocationStatus;
      _exactAlarmStatus = exactAlarmStatus;
      _lastAutoRefreshAt = lastAutoRefreshAt;
      _lastCachedLocationAt = lastCachedLocationAt;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', _soundEnabled);
    await prefs.setBool('vibration_enabled', _vibrationEnabled);
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setInt('minutes_before', _minutesBefore);
    await prefs.setString('calculation_method', _calculationMethod);
    await AlarmSoundService.saveSelection(
      AlarmSoundSelection(
        mode: _alarmSoundMode,
        uri: _alarmSoundUri,
        label: _alarmSoundLabel,
      ),
    );
    await LocationRefreshService.saveSettings(
      mode: _locationRefreshMode,
      dailyHour: _dailyRefreshTime.hour,
      dailyMinute: _dailyRefreshTime.minute,
    );
    if (_locationRefreshMode == LocationRefreshService.modeDailyTime) {
      await LocationRefreshService.requestExactAlarmPermission();
    }
    await LocationRefreshService.scheduleFromSettings();
  }

  Future<void> _pickDailyRefreshTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dailyRefreshTime,
    );
    if (picked == null) return;
    setState(() => _dailyRefreshTime = picked);
  }

  Future<void> _requestLocationWhenInUse() async {
    await Permission.locationWhenInUse.request();
    await _loadSettings();
  }

  Future<void> _requestBackgroundLocation() async {
    await Permission.locationAlways.request();
    await _loadSettings();
  }

  Future<void> _pickAlarmSound() async {
    final selection = await AlarmSoundService.pickCustomAlarmSound();
    if (selection == null || !mounted) return;

    setState(() {
      _alarmSoundMode = selection.mode;
      _alarmSoundUri = selection.uri;
      _alarmSoundLabel = selection.label;
    });
    await AlarmSoundService.saveSelection(selection);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Nada alarm dipilih: ${selection.label}'),
      ),
    );
  }

  Future<void> _useDefaultAlarmSound() async {
    const selection = AlarmSoundService.defaultSelection;
    setState(() {
      _alarmSoundMode = selection.mode;
      _alarmSoundUri = selection.uri;
      _alarmSoundLabel = selection.label;
    });
    await AlarmSoundService.saveSelection(selection);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nada alarm dikembalikan ke default Android'),
      ),
    );
  }

  Future<void> _runNotificationSelfTest() async {
    final scheduledAt = await AlarmService.runNotificationSelfTest();
    final pendingCount = await NotificationService.pendingNotificationCount();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Tes dibuat. Alarm debug dijadwalkan ${DateFormat('HH:mm:ss', 'id_ID').format(scheduledAt)}. Pending: $pendingCount',
        ),
      ),
    );
  }

  Future<void> _runNativeAlarmSelfTest() async {
    final scheduledAt = await AlarmService.runNativeAlarmSelfTest();
    if (!mounted) return;
    if (scheduledAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal membuat alarm native test'),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Alarm native dijadwalkan ${DateFormat('HH:mm:ss', 'id_ID').format(scheduledAt)}',
        ),
      ),
    );
  }

  String _permissionLabel(PermissionStatus status) {
    if (status.isGranted) return 'Diizinkan';
    if (status.isPermanentlyDenied) return 'Ditolak permanen';
    if (status.isDenied) return 'Belum diizinkan';
    if (status.isRestricted) return 'Dibatasi';
    return status.toString();
  }

  String _refreshModeLabel(String mode) {
    switch (mode) {
      case LocationRefreshService.modeHourly:
        return 'Setiap 1 jam';
      case LocationRefreshService.modeEvery3Hours:
        return 'Setiap 3 jam';
      case LocationRefreshService.modeDailyTime:
        return 'Setiap hari pada jam tertentu';
      case LocationRefreshService.modeManual:
      default:
        return 'Manual saja';
    }
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'Belum ada';
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A3A5C),
        title: Text(
          'Pengaturan',
          style: AppTextStyles.nunito(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionTitle('Alarm'),
          _buildCard([
            _buildSwitch(
              'Suara Adzan',
              'Putar adzan saat alarm',
              Icons.volume_up,
              _soundEnabled,
              (v) => setState(() => _soundEnabled = v),
            ),
            _buildSwitch(
              'Getaran',
              'Getar saat alarm berbunyi',
              Icons.vibration,
              _vibrationEnabled,
              (v) => setState(() => _vibrationEnabled = v),
            ),
            _buildSwitch(
              'Notifikasi',
              'Tampilkan notifikasi push',
              Icons.notifications,
              _notificationsEnabled,
              (v) => setState(() => _notificationsEnabled = v),
            ),
            ListTile(
              leading: const Icon(Icons.music_note, color: Color(0xFFD4AF37)),
              title: Text(
                'Nada alarm utama',
                style: AppTextStyles.nunito(color: Colors.white),
              ),
              subtitle: Text(
                _alarmSoundMode == AlarmSoundService.customMode
                    ? 'Kustom: $_alarmSoundLabel'
                    : AlarmSoundService.defaultLabel,
                style: AppTextStyles.nunito(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickAlarmSound,
                    icon: const Icon(Icons.library_music),
                    label: const Text('Pilih dari perangkat'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _alarmSoundMode == AlarmSoundService.defaultMode
                        ? null
                        : _useDefaultAlarmSound,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Pakai default'),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _sectionTitle('Waktu Pengingat'),
          _buildCard([
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ingatkan $_minutesBefore menit sebelum masuk dan sebelum habis',
                    style: AppTextStyles.nunito(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Slider(
                    value: _minutesBefore.toDouble(),
                    min: 5,
                    max: 30,
                    divisions: 5,
                    activeColor: const Color(0xFFD4AF37),
                    inactiveColor: Colors.white24,
                    label: '$_minutesBefore menit',
                    onChanged: (v) =>
                        setState(() => _minutesBefore = v.round()),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _sectionTitle('Lokasi'),
          _buildCard([
            ListTile(
              leading: const Icon(Icons.my_location, color: Color(0xFFD4AF37)),
              title: Text(
                'Izin lokasi saat aplikasi dibuka',
                style: AppTextStyles.nunito(color: Colors.white),
              ),
              subtitle: Text(
                _permissionLabel(_locationStatus),
                style: AppTextStyles.nunito(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              trailing: TextButton(
                onPressed: _requestLocationWhenInUse,
                child: const Text('Minta izin'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.route, color: Color(0xFFD4AF37)),
              title: Text(
                'Izin lokasi latar belakang',
                style: AppTextStyles.nunito(color: Colors.white),
              ),
              subtitle: Text(
                _permissionLabel(_backgroundLocationStatus),
                style: AppTextStyles.nunito(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              trailing: TextButton(
                onPressed: _requestBackgroundLocation,
                child: const Text('Minta izin'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.schedule, color: Color(0xFFD4AF37)),
              title: Text(
                'Cache lokasi terakhir',
                style: AppTextStyles.nunito(color: Colors.white),
              ),
              subtitle: Text(
                _formatDateTime(_lastCachedLocationAt),
                style: AppTextStyles.nunito(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _sectionTitle('Refresh Lokasi'),
          _buildCard([
            ListTile(
              leading: const Icon(Icons.autorenew, color: Color(0xFFD4AF37)),
              title: Text(
                'Mode pembaruan lokasi',
                style: AppTextStyles.nunito(color: Colors.white),
              ),
              subtitle: Text(
                _refreshModeLabel(_locationRefreshMode),
                style: AppTextStyles.nunito(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: DropdownButtonFormField<String>(
                initialValue: _locationRefreshMode,
                dropdownColor: const Color(0xFF162233),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                ),
                style: AppTextStyles.nunito(color: Colors.white),
                items: const [
                  DropdownMenuItem(
                    value: LocationRefreshService.modeManual,
                    child: Text('Manual saja'),
                  ),
                  DropdownMenuItem(
                    value: LocationRefreshService.modeHourly,
                    child: Text('Setiap 1 jam'),
                  ),
                  DropdownMenuItem(
                    value: LocationRefreshService.modeEvery3Hours,
                    child: Text('Setiap 3 jam'),
                  ),
                  DropdownMenuItem(
                    value: LocationRefreshService.modeDailyTime,
                    child: Text('Setiap hari pada jam tertentu'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _locationRefreshMode = value);
                },
              ),
            ),
            if (_locationRefreshMode == LocationRefreshService.modeDailyTime)
              ListTile(
                leading:
                    const Icon(Icons.access_time, color: Color(0xFFD4AF37)),
                title: Text(
                  'Jam refresh harian',
                  style: AppTextStyles.nunito(color: Colors.white),
                ),
                subtitle: Text(
                  _dailyRefreshTime.format(context),
                  style: AppTextStyles.nunito(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                trailing: TextButton(
                  onPressed: _pickDailyRefreshTime,
                  child: const Text('Pilih jam'),
                ),
              ),
            ListTile(
              leading:
                  const Icon(Icons.alarm_on, color: Color(0xFFD4AF37)),
              title: Text(
                'Izin exact alarm',
                style: AppTextStyles.nunito(color: Colors.white),
              ),
              subtitle: Text(
                _permissionLabel(_exactAlarmStatus),
                style: AppTextStyles.nunito(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              trailing: TextButton(
                onPressed: () async {
                  await LocationRefreshService.requestExactAlarmPermission();
                  await _loadSettings();
                },
                child: const Text('Aktifkan'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.history, color: Color(0xFFD4AF37)),
              title: Text(
                'Refresh otomatis terakhir',
                style: AppTextStyles.nunito(color: Colors.white),
              ),
              subtitle: Text(
                _formatDateTime(_lastAutoRefreshAt),
                style: AppTextStyles.nunito(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _sectionTitle('Metode Perhitungan'),
          _buildCard([
            Padding(
              padding: const EdgeInsets.all(8),
              child: RadioGroup<String>(
                onChanged: (v) => setState(() => _calculationMethod = v!),
                groupValue: _calculationMethod,
                child: Column(
                  children: _methods.entries.map((e) {
                    return RadioListTile<String>(
                      title: Text(
                        e.value,
                        style: AppTextStyles.nunito(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      value: e.key,
                      activeColor: const Color(0xFFD4AF37),
                    );
                  }).toList(),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _sectionTitle('Lainnya'),
          _buildCard([
            ListTile(
              leading: const Icon(Icons.location_off, color: Color(0xFFD4AF37)),
              title: Text(
                'Reset Cache Lokasi',
                style: AppTextStyles.nunito(color: Colors.white),
              ),
              subtitle: Text(
                'Paksa deteksi ulang GPS',
                style: AppTextStyles.nunito(color: Colors.white54, fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
              onTap: () async {
                await LocationService.clearCache();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cache lokasi dihapus')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.alarm_off, color: Colors.redAccent),
              title: Text(
                'Batalkan Semua Alarm',
                style: AppTextStyles.nunito(color: Colors.redAccent),
              ),
              onTap: () async {
                await AlarmService.cancelAll();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Semua alarm dibatalkan')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.bug_report, color: Color(0xFFD4AF37)),
              title: Text(
                'Tes Notifikasi & Alarm',
                style: AppTextStyles.nunito(color: Colors.white),
              ),
              subtitle: Text(
                'Kirim notifikasi sekarang dan jadwalkan alarm debug 45 detik.',
                style: AppTextStyles.nunito(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
              onTap: _runNotificationSelfTest,
            ),
            ListTile(
              leading: const Icon(Icons.alarm, color: Color(0xFFD4AF37)),
              title: Text(
                'Tes Alarm Native Android',
                style: AppTextStyles.nunito(color: Colors.white),
              ),
              subtitle: Text(
                'Buat alarm gaya Android default, berbunyi 1 menit dari sekarang.',
                style: AppTextStyles.nunito(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
              onTap: _runNativeAlarmSelfTest,
            ),
          ]),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await _saveSettings();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Pengaturan disimpan'),
                    backgroundColor: Color(0xFF1A5C3A),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Simpan Pengaturan',
                style: AppTextStyles.nunito(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
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
          color: const Color(0xFFD4AF37),
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
        color: const Color(0xFF162233),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitch(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      secondary: Icon(icon, color: const Color(0xFFD4AF37)),
      title: Text(
        title,
        style: AppTextStyles.nunito(color: Colors.white, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.nunito(color: Colors.white54, fontSize: 12),
      ),
      value: value,
      activeTrackColor: const Color(0xFFD4AF37),
      onChanged: onChanged,
    );
  }
}
