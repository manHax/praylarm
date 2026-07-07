import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prayer_alarm_app/models/khatam_plan.dart';
import 'package:prayer_alarm_app/theme/app_text_styles.dart';

class KhatamPlannerScreen extends StatefulWidget {
  const KhatamPlannerScreen({super.key});

  @override
  State<KhatamPlannerScreen> createState() => _KhatamPlannerScreenState();
}

class _KhatamPlannerScreenState extends State<KhatamPlannerScreen> {
  static const _prefsKey = 'khatam_planner_state_v1';

  late final TextEditingController _pagesController;
  late final TextEditingController _ayatController;
  late final TextEditingController _khatamController;

  KhatamPlannerState _planner = KhatamPlannerState.initial();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pagesController = TextEditingController();
    _ayatController = TextEditingController();
    _khatamController = TextEditingController();
    _loadState();
  }

  @override
  void dispose() {
    _pagesController.dispose();
    _ayatController.dispose();
    _khatamController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    KhatamPlannerState nextState = KhatamPlannerState.initial();

    if (raw != null) {
      try {
        nextState = KhatamPlannerState.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } catch (_) {
        nextState = KhatamPlannerState.initial();
      }
    }

    _syncControllers(nextState);
    if (!mounted) return;
    setState(() {
      _planner = nextState;
      _isLoading = false;
    });
  }

  Future<void> _persist(KhatamPlannerState nextState) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(nextState.toJson()));
  }

  void _syncControllers(KhatamPlannerState state) {
    _pagesController.text = state.totalPages.toString();
    _ayatController.text = state.totalAyat.toString();
    _khatamController.text = state.khatamTimes.toString();
  }

  Future<void> _updatePlanner(KhatamPlannerState nextState) async {
    setState(() => _planner = nextState);
    await _persist(nextState);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initialDate = isStart ? _planner.startDate : _planner.endDate;
    final firstDate = DateTime.now().subtract(const Duration(days: 3650));
    final lastDate = DateTime.now().add(const Duration(days: 3650));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked == null) return;

    if (isStart) {
      final newStart = DateTime(picked.year, picked.month, picked.day);
      final newEnd = _planner.endDate.isBefore(newStart)
          ? newStart
          : _planner.endDate;
      await _updatePlanner(
        _planner.copyWith(
          startDate: newStart,
          endDate: newEnd,
          doneDays: const {},
          doneSlots: const {},
        ),
      );
      return;
    }

    final newEnd = DateTime(picked.year, picked.month, picked.day);
    final safeEnd = newEnd.isBefore(_planner.startDate)
        ? _planner.startDate
        : newEnd;
    await _updatePlanner(
      _planner.copyWith(
        endDate: safeEnd,
        doneDays: const {},
        doneSlots: const {},
      ),
    );
  }

  Future<void> _saveNumbers() async {
    final totalPages = _sanitizeNumber(_pagesController.text, fallback: 604);
    final totalAyat = _sanitizeNumber(_ayatController.text, fallback: 6236);
    final khatamTimes = _sanitizeNumber(_khatamController.text, fallback: 1);

    _pagesController.text = totalPages.toString();
    _ayatController.text = totalAyat.toString();
    _khatamController.text = khatamTimes.toString();

    await _updatePlanner(
      _planner.copyWith(
        totalPages: totalPages,
        totalAyat: totalAyat,
        khatamTimes: khatamTimes,
        doneDays: const {},
        doneSlots: const {},
      ),
    );
  }

  int _sanitizeNumber(String raw, {required int fallback}) {
    final parsed = int.tryParse(raw.trim());
    if (parsed == null || parsed < 1) return fallback;
    return parsed;
  }

  Future<void> _togglePrayerSlot(String slot) async {
    final currentSlots = List<String>.from(_planner.prayerSlots);
    if (currentSlots.contains(slot)) {
      currentSlots.remove(slot);
    } else {
      currentSlots.add(slot);
    }

    final normalizedSlots = currentSlots.isEmpty
        ? List<String>.from(KhatamPlannerState.defaultPrayerSlots)
        : currentSlots;

    await _updatePlanner(
      _planner.copyWith(
        prayerSlots: normalizedSlots,
        doneDays: const {},
        doneSlots: const {},
      ),
    );
  }

  Future<void> _toggleDay(KhatamDayPlan day) async {
    final nextDoneDays = Map<int, bool>.from(_planner.doneDays);
    nextDoneDays[day.day] = !(_planner.doneDays[day.day] ?? false);
    await _updatePlanner(_planner.copyWith(doneDays: nextDoneDays));
  }

  Future<void> _toggleSlot(KhatamDayPlan day, int slotIndex) async {
    final nextDoneSlots = Map<String, bool>.from(_planner.doneSlots);
    final key = _planner.slotKey(day.day, slotIndex);
    nextDoneSlots[key] = !(_planner.doneSlots[key] ?? false);
    await _updatePlanner(_planner.copyWith(doneSlots: nextDoneSlots));
  }

  Future<void> _toggleWholeDay(KhatamDayPlan day) async {
    final dayDone = _planner.isDayDone(day);
    final nextDoneSlots = Map<String, bool>.from(_planner.doneSlots);
    for (var index = 0; index < day.slots.length; index++) {
      nextDoneSlots[_planner.slotKey(day.day, index)] = !dayDone;
    }
    await _updatePlanner(_planner.copyWith(doneSlots: nextDoneSlots));
  }

  Future<void> _resetChecklist() async {
    await _updatePlanner(
      _planner.copyWith(doneDays: const {}, doneSlots: const {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A3A5C),
          title: const Text('Planner Khatam'),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
        ),
      );
    }

    final plan = _planner.buildPlan();
    final doneCount = _planner.completedChecklistItems;
    final totalCount = _planner.totalChecklistItems;
    final progress = totalCount == 0 ? 0.0 : doneCount / totalCount;
    final avgPerDay = _planner.totalTarget / _planner.totalDays;
    final avgPerSlot = _planner.totalTarget / plan.totalSlots;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A3A5C),
        title: Text(
          'Planner Khatam',
          style: AppTextStyles.nunito(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionTitle('Target Bacaan'),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<KhatamUnit>(
                  segments: const [
                    ButtonSegment(
                      value: KhatamUnit.pages,
                      icon: Icon(Icons.book_outlined),
                      label: Text('Halaman'),
                    ),
                    ButtonSegment(
                      value: KhatamUnit.ayat,
                      icon: Icon(Icons.format_list_numbered),
                      label: Text('Ayat'),
                    ),
                  ],
                  selected: {_planner.unit},
                  onSelectionChanged: (selection) {
                    _updatePlanner(
                      _planner.copyWith(
                        unit: selection.first,
                        doneDays: const {},
                        doneSlots: const {},
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                if (_planner.unit == KhatamUnit.pages)
                  _buildNumberField(
                    label: 'Total halaman',
                    helper: 'Default mushaf Madinah 604 halaman.',
                    controller: _pagesController,
                  )
                else
                  _buildNumberField(
                    label: 'Total ayat',
                    helper: 'Default 6236 ayat.',
                    controller: _ayatController,
                  ),
                const SizedBox(height: 12),
                _buildNumberField(
                  label: 'Target khatam',
                  helper: 'Misal 2 berarti target khatam dua kali.',
                  controller: _khatamController,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDateButton(
                        label: 'Mulai',
                        value: _planner.startDate,
                        onTap: () => _pickDate(isStart: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDateButton(
                        label: 'Selesai',
                        value: _planner.endDate,
                        onTap: () => _pickDate(isStart: false),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle('Mode Pembagian'),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<KhatamMode>(
                  segments: const [
                    ButtonSegment(
                      value: KhatamMode.perDay,
                      icon: Icon(Icons.today_outlined),
                      label: Text('Per Hari'),
                    ),
                    ButtonSegment(
                      value: KhatamMode.perPrayer,
                      icon: Icon(Icons.access_time),
                      label: Text('Per Sholat'),
                    ),
                  ],
                  selected: {_planner.mode},
                  onSelectionChanged: (selection) {
                    final nextMode = selection.first;
                    _updatePlanner(
                      _planner.copyWith(
                        mode: nextMode,
                        prayerSlots: nextMode == KhatamMode.perPrayer
                            ? (_planner.prayerSlots.isEmpty
                                ? List<String>.from(
                                    KhatamPlannerState.defaultPrayerSlots,
                                  )
                                : _planner.prayerSlots)
                            : _planner.prayerSlots,
                        doneDays: const {},
                        doneSlots: const {},
                      ),
                    );
                  },
                ),
                if (_planner.mode == KhatamMode.perPrayer) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Slot sholat aktif',
                    style: AppTextStyles.nunito(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: KhatamPlannerState.defaultPrayerSlots.map((slot) {
                      final selected = _planner.prayerSlots.contains(slot);
                      return FilterChip(
                        selected: selected,
                        label: Text(slot),
                        onSelected: (_) => _togglePrayerSlot(slot),
                        selectedColor:
                            const Color(0xFFD4AF37).withValues(alpha: 0.2),
                        checkmarkColor: const Color(0xFFD4AF37),
                        labelStyle: AppTextStyles.nunito(
                          color: selected
                              ? const Color(0xFFD4AF37)
                              : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pembagian slot akan mengikuti sholat yang dipilih.',
                    style: AppTextStyles.nunito(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _planner.spreadRemainder,
                  activeTrackColor: const Color(0xFFD4AF37),
                  onChanged: (value) {
                    _updatePlanner(
                      _planner.copyWith(
                        spreadRemainder: value,
                        doneDays: const {},
                        doneSlots: const {},
                      ),
                    );
                  },
                  title: Text(
                    'Sebar sisa ke slot awal',
                    style: AppTextStyles.nunito(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    _planner.spreadRemainder
                        ? 'Slot awal akan mendapat tambahan 1 ${_planner.unitLabel} jika ada sisa.'
                        : 'Semua slot dibulatkan ke atas, slot akhir bisa lebih pendek.',
                    style: AppTextStyles.nunito(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle('Ringkasan'),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildStatChip(
                      '${_planner.totalTarget} ${_planner.unitLabel}',
                    ),
                    _buildStatChip('${_planner.totalDays} hari'),
                    _buildStatChip('${plan.totalSlots} slot'),
                    _buildStatChip('${_planner.khatamTimes}x khatam'),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Rata-rata ${avgPerDay.toStringAsFixed(2)} ${_planner.unitLabel} per hari',
                  style: AppTextStyles.nunito(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rata-rata ${avgPerSlot.toStringAsFixed(2)} ${_planner.unitLabel} per slot',
                  style: AppTextStyles.nunito(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  _planner.spreadRemainder
                      ? 'Base ${plan.basePerSlot} ${_planner.unitLabel}, +1 ke ${plan.distributedRemainder} slot awal.'
                      : 'Base ${plan.basePerSlot} ${_planner.unitLabel}, slot akhir bisa lebih pendek.',
                  style: AppTextStyles.nunito(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle('Checklist'),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$doneCount / $totalCount selesai',
                            style: AppTextStyles.nunito(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: Colors.white12,
                            color: const Color(0xFFD4AF37),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: _resetChecklist,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Reset'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle('Rencana Harian'),
          ...plan.days.map(_buildDayCard),
          const SizedBox(height: 16),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tips',
                  style: AppTextStyles.nunito(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Untuk Ramadan, gunakan 29 atau 30 hari dengan mode per sholat agar target lebih ringan setelah tiap waktu sholat.',
                  style: AppTextStyles.nunito(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard(KhatamDayPlan day) {
    final dayDone = _planner.isDayDone(day);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF162233),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dayDone
              ? const Color(0xFFD4AF37).withValues(alpha: 0.5)
              : Colors.white10,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: day.day <= 2,
          iconColor: Colors.white70,
          collapsedIconColor: Colors.white38,
          title: Row(
            children: [
              Checkbox(
                value: dayDone,
                activeColor: const Color(0xFFD4AF37),
                onChanged: (_) {
                  if (_planner.mode == KhatamMode.perDay) {
                    _toggleDay(day);
                    return;
                  }
                  _toggleWholeDay(day);
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hari ${day.day}',
                      style: AppTextStyles.nunito(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_planner.formatWrappedRange(day.start, day.end)} • ${day.totalThisDay} ${_planner.unitLabel}',
                      style: AppTextStyles.nunito(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          children: _planner.mode == KhatamMode.perPrayer
              ? [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: List.generate(day.slots.length, (index) {
                        final slot = day.slots[index];
                        final label = _planner.prayerSlots[index];
                        final checked = _planner.doneSlots[
                              _planner.slotKey(day.day, index)
                            ] ==
                            true;

                        return GestureDetector(
                          onTap: () => _toggleSlot(day, index),
                          child: Container(
                            width:
                                (MediaQuery.of(context).size.width - 76) / 2,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: checked
                                  ? const Color(0xFFD4AF37)
                                      .withValues(alpha: 0.12)
                                  : const Color(0xFF0F1A28),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: checked
                                    ? const Color(0xFFD4AF37)
                                    : Colors.white10,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        label,
                                        style: AppTextStyles.nunito(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Checkbox(
                                      value: checked,
                                      activeColor: const Color(0xFFD4AF37),
                                      onChanged: (_) => _toggleSlot(day, index),
                                    ),
                                  ],
                                ),
                                Text(
                                  _planner.formatWrappedRange(
                                    slot.start,
                                    slot.end,
                                  ),
                                  style: AppTextStyles.nunito(
                                    color: const Color(0xFFD4AF37),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${slot.size} ${_planner.unitLabel}',
                                  style: AppTextStyles.nunito(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ]
              : const [],
        ),
      ),
    );
  }

  Widget _buildDateButton({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1A28),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.nunito(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('dd MMM yyyy', 'id_ID').format(value),
              style: AppTextStyles.nunito(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required String helper,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.nunito(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: AppTextStyles.nunito(color: Colors.white),
          onSubmitted: (_) {
            _saveNumbers();
          },
          onTapOutside: (_) {
            _saveNumbers();
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF0F1A28),
            hintText: label,
            hintStyle: AppTextStyles.nunito(color: Colors.white24),
            helperText: helper,
            helperStyle: AppTextStyles.nunito(
              color: Colors.white38,
              fontSize: 11,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFD4AF37).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.nunito(
          color: const Color(0xFFD4AF37),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF162233),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
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
}
