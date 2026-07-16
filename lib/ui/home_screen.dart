// lib/ui/home_screen.dart

import 'dart:async';
import 'package:prayer_alarm_app/theme/app_colors.dart';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prayer_alarm_app/models/prayer_time.dart';
import 'package:prayer_alarm_app/services/location_service.dart';
import 'package:prayer_alarm_app/services/prayer_api_service.dart';
import 'package:prayer_alarm_app/services/alarm_service.dart';
import 'package:prayer_alarm_app/theme/app_text_styles.dart';
import 'package:prayer_alarm_app/ui/khatam_planner_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PrayerTimes? _prayerTimes;
  bool _isLoading = true;
  String? _error;
  String _locationStatus = 'Mendeteksi lokasi...';
  LocationSnapshot? _activeLocation;
  bool _notificationsEnabled = true;
  int _minutesBefore = 10;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadPrayerTimes();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _minutesBefore = prefs.getInt('minutes_before') ?? 10;
    });
  }

  Future<void> _loadPrayerTimes() async {
    await _loadPrayerTimesInternal(ignoreCache: false);
  }

  Future<void> _refreshPrayerTimes() async {
    await _loadPrayerTimesInternal(ignoreCache: true);
  }

  Future<void> _loadPrayerTimesInternal({required bool ignoreCache}) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _locationStatus = 'Mendeteksi lokasi...';
      _activeLocation = null;
    });

    try {
      setState(() => _locationStatus = 'Mengambil koordinat GPS...');
      final location =
          await LocationService.getCurrentLocation(ignoreCache: ignoreCache);

      setState(() => _locationStatus = 'Mengambil jadwal sholat...');
      final times = await PrayerApiService.getPrayerTimes(
        lat: location.lat,
        lng: location.lng,
      );

      setState(() {
        _prayerTimes = times;
        _activeLocation = location;
        _isLoading = false;
      });

      unawaited(_scheduleAlarmsInBackground(times));
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _scheduleAlarmsInBackground(PrayerTimes times) async {
    try {
      await AlarmService.scheduleAllAlarms(times);
    } catch (error, stackTrace) {
      debugPrint('Background alarm scheduling failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoading && _error == null && _prayerTimes == null) {
      return Scaffold(
        backgroundColor: context.colors.scaffoldBackground,
        body: SafeArea(child: _buildLoading()),
      );
    }

    return Scaffold(
      backgroundColor: context.colors.scaffoldBackground,
      body: SafeArea(
        child: _isLoading
            ? _buildLoading()
            : _error != null
                ? _buildError()
                : _buildContent(),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              color: context.colors.primaryAccent,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _locationStatus,
            style: AppTextStyles.nunito(
              color: context.colors.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              'Gagal memuat jadwal',
              style: AppTextStyles.nunito(
                color: context.colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              style: AppTextStyles.nunito(color: context.colors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshPrayerTimes,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.primaryAccent,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final pt = _prayerTimes!;
    final next = AlarmService.getNextPrayer(pt);
    final duration = AlarmService.getTimeUntilNextPrayer(pt);

    return CustomScrollView(
      slivers: [
        // ── Header ──────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _buildHeader(pt, next, duration),
        ),
        // ── Prayer Cards ─────────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final prayer = pt.allPrayers[index];
                final isNext = prayer.name == next?.name;
                return _PrayerCard(
                  prayer: prayer,
                  isNext: isNext,
                  index: index,
                  notificationsEnabled: _notificationsEnabled,
                  minutesBefore: _minutesBefore,
                );
              },
              childCount: pt.allPrayers.length,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _buildRelatedTimesSection(pt),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildHeader(
      PrayerTimes pt, PrayerEntry? next, Duration? duration) {
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(now);
    final locationTitle =
        _activeLocation?.primaryLabel ?? pt.inferredLocationName;
    final locationSubtitle = _activeLocation?.secondaryLabel;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [context.colors.appBarBackground, context.colors.scaffoldBackground],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🕌 Jadwal Sholat',
                      style: AppTextStyles.nunito(
                        color: context.colors.primaryAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: AppTextStyles.nunito(
                        color: context.colors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          color: context.colors.primaryAccent,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            locationTitle,
                            style: AppTextStyles.nunito(
                              color: context.colors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    if (locationSubtitle != null &&
                        locationSubtitle.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          locationSubtitle,
                          style: AppTextStyles.nunito(
                            color: context.colors.iconMuted,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    if (_activeLocation != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          children: [
                            Text(
                              'Koordinat ${pt.coordinateLabel}',
                              style: AppTextStyles.nunito(
                                color: context.colors.iconMuted,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              'Elevasi ${_activeLocation!.altitude.toStringAsFixed(0)} m',
                              style: AppTextStyles.nunito(
                                color: context.colors.iconMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_activeLocation == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Koordinat ${pt.coordinateLabel}',
                          style: AppTextStyles.nunito(
                            color: context.colors.iconMuted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                children: [
                  IconButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const KhatamPlannerScreen(),
                        ),
                      );
                    },
                    icon: Icon(Icons.menu_book, color: context.colors.textSecondary),
                    tooltip: 'Planner khatam',
                  ),
                  IconButton(
                    onPressed: _refreshPrayerTimes,
                    icon: Icon(Icons.refresh, color: context.colors.textSecondary),
                    tooltip: 'Refresh',
                  ),
                  IconButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                      await _loadSettings();
                      await _loadPrayerTimes();
                    },
                    icon: Icon(Icons.settings, color: context.colors.textSecondary),
                  ),
                ],
              ),
            ],
          ),

          if (next != null && duration != null) ...[
            const SizedBox(height: 24),
            // Next prayer countdown card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [context.colors.primaryAccent, context.colors.primaryAccentDark],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.primaryAccent.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    next.iconEmoji,
                    style: const TextStyle(fontSize: 48),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sholat Berikutnya',
                          style: AppTextStyles.nunito(
                            color: Colors.black54,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          next.name,
                          style: AppTextStyles.nunito(
                            color: Colors.black,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          next.arabicName,
                          style: AppTextStyles.amiri(
                            color: Colors.black87,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        next.start,
                        style: AppTextStyles.nunito(
                          color: Colors.black,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      _CountdownTimer(duration: duration),
                    ],
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 500.ms)
                .slideY(begin: 0.2, end: 0),
          ],
        ],
      ),
    );
  }

  Widget _buildRelatedTimesSection(PrayerTimes pt) {
    final relatedTimes = pt.relatedTimes;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Waktu Terkait',
            style: AppTextStyles.nunito(
              color: context.colors.primaryAccent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: relatedTimes
                .map((entry) => _RelatedTimeCard(entry: entry))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Prayer Card Widget
// ─────────────────────────────────────────────────────────────────────────────

class _PrayerCard extends StatelessWidget {
  final PrayerEntry prayer;
  final bool isNext;
  final int index;
  final bool notificationsEnabled;
  final int minutesBefore;

  const _PrayerCard({
    required this.prayer,
    required this.isNext,
    required this.index,
    required this.notificationsEnabled,
    required this.minutesBefore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isNext
            ? context.colors.appBarBackground
            : context.colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: isNext
            ? Border.all(color: context.colors.primaryAccent, width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isNext
                  ? context.colors.primaryAccent.withValues(alpha: 0.15)
                  : context.colors.textPrimary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                prayer.iconEmoji,
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      prayer.name,
                      style: AppTextStyles.nunito(
                        color: isNext
                            ? context.colors.primaryAccent
                            : context.colors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isNext) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: context.colors.primaryAccent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'BERIKUTNYA',
                          style: AppTextStyles.nunito(
                            color: Colors.black,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Berakhir: ${prayer.end}',
                  style: AppTextStyles.nunito(
                    color: context.colors.iconMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                prayer.start,
                style: AppTextStyles.nunito(
                  color: isNext ? context.colors.primaryAccent : context.colors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                notificationsEnabled ? '⏰ -$minutesBefore mnt' : '🔕 Off',
                style: AppTextStyles.nunito(
                  color: context.colors.iconMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate(delay: (index * 80).ms)
        .fadeIn(duration: 400.ms)
        .slideX(begin: 0.1, end: 0);
  }
}

class _RelatedTimeCard extends StatelessWidget {
  final RelatedTimeEntry entry;

  const _RelatedTimeCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 52) / 2;

    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.iconEmoji,
            style: const TextStyle(fontSize: 22),
          ),
          const SizedBox(height: 10),
          Text(
            entry.name,
            style: AppTextStyles.nunito(
              color: context.colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            entry.time,
            style: AppTextStyles.nunito(
              color: context.colors.primaryAccent,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            entry.description,
            style: AppTextStyles.nunito(
              color: context.colors.iconMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Countdown Timer Widget
// ─────────────────────────────────────────────────────────────────────────────

class _CountdownTimer extends StatefulWidget {
  final Duration duration;
  const _CountdownTimer({required this.duration});

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.duration;
    // Update setiap detik
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        _remaining = _remaining - const Duration(seconds: 1);
      });
      return _remaining.inSeconds > 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = _remaining.inHours;
    final m = _remaining.inMinutes % 60;
    final s = _remaining.inSeconds % 60;

    return Text(
      h > 0
          ? '${h}j ${m.toString().padLeft(2, '0')}m'
          : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
      style: AppTextStyles.nunito(
        color: Colors.black87,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
