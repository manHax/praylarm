enum KhatamUnit { pages, ayat }

enum KhatamMode { perDay, perPrayer }

class KhatamSlotPlan {
  final int index;
  final int? start;
  final int? end;
  final int size;

  const KhatamSlotPlan({
    required this.index,
    required this.start,
    required this.end,
    required this.size,
  });
}

class KhatamDayPlan {
  final int day;
  final List<KhatamSlotPlan> slots;
  final int? start;
  final int? end;
  final int totalThisDay;

  const KhatamDayPlan({
    required this.day,
    required this.slots,
    required this.start,
    required this.end,
    required this.totalThisDay,
  });
}

class KhatamPlanResult {
  final List<KhatamDayPlan> days;
  final int basePerSlot;
  final int distributedRemainder;
  final int totalSlots;

  const KhatamPlanResult({
    required this.days,
    required this.basePerSlot,
    required this.distributedRemainder,
    required this.totalSlots,
  });
}

class KhatamPlannerState {
  static const defaultPrayerSlots = [
    'Subuh',
    'Dzuhur',
    'Ashar',
    'Maghrib',
    'Isya',
  ];

  final KhatamUnit unit;
  final int totalPages;
  final int totalAyat;
  final DateTime startDate;
  final DateTime endDate;
  final int khatamTimes;
  final bool spreadRemainder;
  final KhatamMode mode;
  final List<String> prayerSlots;
  final Map<int, bool> doneDays;
  final Map<String, bool> doneSlots;

  const KhatamPlannerState({
    required this.unit,
    required this.totalPages,
    required this.totalAyat,
    required this.startDate,
    required this.endDate,
    required this.khatamTimes,
    required this.spreadRemainder,
    required this.mode,
    required this.prayerSlots,
    required this.doneDays,
    required this.doneSlots,
  });

  factory KhatamPlannerState.initial() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return KhatamPlannerState(
      unit: KhatamUnit.pages,
      totalPages: 604,
      totalAyat: 6236,
      startDate: start,
      endDate: start.add(const Duration(days: 29)),
      khatamTimes: 1,
      spreadRemainder: true,
      mode: KhatamMode.perPrayer,
      prayerSlots: List<String>.from(defaultPrayerSlots),
      doneDays: const {},
      doneSlots: const {},
    );
  }

  factory KhatamPlannerState.fromJson(Map<String, dynamic> json) {
    return KhatamPlannerState(
      unit: json['unit'] == 'ayat' ? KhatamUnit.ayat : KhatamUnit.pages,
      totalPages: _safeInt(json['totalPages'], 604),
      totalAyat: _safeInt(json['totalAyat'], 6236),
      startDate: DateTime.tryParse(json['startDate'] as String? ?? '') ??
          DateTime.now(),
      endDate: DateTime.tryParse(json['endDate'] as String? ?? '') ??
          DateTime.now().add(const Duration(days: 29)),
      khatamTimes: _safeInt(json['khatamTimes'], 1),
      spreadRemainder: json['spreadRemainder'] as bool? ?? true,
      mode: json['mode'] == 'perDay'
          ? KhatamMode.perDay
          : KhatamMode.perPrayer,
      prayerSlots: (json['prayerSlots'] as List<dynamic>? ?? defaultPrayerSlots)
          .map((slot) => slot.toString())
          .toList(),
      doneDays: (json['doneDays'] as Map<String, dynamic>? ?? const {})
          .map((key, value) => MapEntry(int.parse(key), value == true)),
      doneSlots: (json['doneSlots'] as Map<String, dynamic>? ?? const {})
          .map((key, value) => MapEntry(key, value == true)),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'unit': unit == KhatamUnit.ayat ? 'ayat' : 'pages',
      'totalPages': totalPages,
      'totalAyat': totalAyat,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'khatamTimes': khatamTimes,
      'spreadRemainder': spreadRemainder,
      'mode': mode == KhatamMode.perDay ? 'perDay' : 'perPrayer',
      'prayerSlots': prayerSlots,
      'doneDays': doneDays.map((key, value) => MapEntry('$key', value)),
      'doneSlots': doneSlots,
    };
  }

  int get cycleSize => unit == KhatamUnit.pages ? totalPages : totalAyat;

  int get totalTarget => cycleSize * khatamTimes;

  int get totalDays {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final diff = end.difference(start).inDays;
    return diff < 0 ? 1 : diff + 1;
  }

  int get activePrayerSlotsCount {
    if (mode == KhatamMode.perDay) return 1;
    return prayerSlots.isEmpty ? defaultPrayerSlots.length : prayerSlots.length;
  }

  String get unitLabel => unit == KhatamUnit.ayat ? 'ayat' : 'halaman';

  int get totalChecklistItems {
    final plan = buildPlan();
    if (mode == KhatamMode.perDay) return plan.days.length;
    return plan.days.fold<int>(0, (sum, day) => sum + day.slots.length);
  }

  int get completedChecklistItems {
    final plan = buildPlan();
    if (mode == KhatamMode.perDay) {
      return plan.days.where((day) => doneDays[day.day] == true).length;
    }

    var count = 0;
    for (final day in plan.days) {
      for (var i = 0; i < day.slots.length; i++) {
        if (doneSlots[slotKey(day.day, i)] == true) {
          count++;
        }
      }
    }
    return count;
  }

  KhatamPlanResult buildPlan() {
    final days = totalDays < 1 ? 1 : totalDays;
    final prayersPerDay = activePrayerSlotsCount;
    final totalSlots =
        mode == KhatamMode.perPrayer ? days * prayersPerDay : days;
    final base = spreadRemainder
        ? totalTarget ~/ totalSlots
        : _ceilDiv(totalTarget, totalSlots);
    final remainder = spreadRemainder
        ? totalTarget - (base * totalSlots)
        : (base * totalSlots) - totalTarget;

    final slotSizes = <int>[];
    for (var i = 0; i < totalSlots; i++) {
      if (spreadRemainder) {
        slotSizes.add(base + (i < remainder ? 1 : 0));
      } else {
        slotSizes.add(base);
      }
    }

    final slots = <KhatamSlotPlan>[];
    var cursor = 1;
    for (var i = 0; i < totalSlots; i++) {
      if (cursor > totalTarget) {
        slots.add(KhatamSlotPlan(index: i + 1, start: null, end: null, size: 0));
        continue;
      }

      final size = slotSizes[i];
      final start = cursor;
      final end = _min(totalTarget, cursor + size - 1);
      slots.add(
        KhatamSlotPlan(
          index: i + 1,
          start: start,
          end: end,
          size: end - start + 1,
        ),
      );
      cursor = end + 1;
    }

    final dayPlans = <KhatamDayPlan>[];
    if (mode == KhatamMode.perDay) {
      for (var dayIndex = 0; dayIndex < days; dayIndex++) {
        final slot = slots[dayIndex];
        dayPlans.add(
          KhatamDayPlan(
            day: dayIndex + 1,
            slots: [slot],
            start: slot.start,
            end: slot.end,
            totalThisDay: slot.size,
          ),
        );
      }
    } else {
      for (var dayIndex = 0; dayIndex < days; dayIndex++) {
        final startIndex = dayIndex * prayersPerDay;
        final daySlots = slots.sublist(startIndex, startIndex + prayersPerDay);
        dayPlans.add(
          KhatamDayPlan(
            day: dayIndex + 1,
            slots: daySlots,
            start: daySlots.firstWhere(
              (slot) => slot.start != null,
              orElse: () => const KhatamSlotPlan(
                index: 0,
                start: null,
                end: null,
                size: 0,
              ),
            ).start,
            end: daySlots.lastWhere(
              (slot) => slot.end != null,
              orElse: () => const KhatamSlotPlan(
                index: 0,
                start: null,
                end: null,
                size: 0,
              ),
            ).end,
            totalThisDay:
                daySlots.fold<int>(0, (sum, slot) => sum + slot.size),
          ),
        );
      }
    }

    return KhatamPlanResult(
      days: dayPlans,
      basePerSlot: base,
      distributedRemainder: remainder,
      totalSlots: totalSlots,
    );
  }

  bool isDayDone(KhatamDayPlan day) {
    if (mode == KhatamMode.perDay) {
      return doneDays[day.day] == true;
    }

    for (var i = 0; i < day.slots.length; i++) {
      if (doneSlots[slotKey(day.day, i)] != true) {
        return false;
      }
    }
    return day.slots.isNotEmpty;
  }

  String formatWrappedRange(int? start, int? end) {
    if (start == null || end == null) return 'Selesai';

    final cycleStart = ((start - 1) ~/ cycleSize) + 1;
    final cycleEnd = ((end - 1) ~/ cycleSize) + 1;
    final wrappedStart = ((start - 1) % cycleSize) + 1;
    final wrappedEnd = ((end - 1) % cycleSize) + 1;

    if (cycleStart == cycleEnd) {
      return 'K$cycleStart $wrappedStart-$wrappedEnd';
    }

    return 'K$cycleStart $wrappedStart-$cycleSize + '
        'K$cycleEnd 1-$wrappedEnd';
  }

  String slotKey(int day, int slotIndex) => '$day:$slotIndex';

  KhatamPlannerState copyWith({
    KhatamUnit? unit,
    int? totalPages,
    int? totalAyat,
    DateTime? startDate,
    DateTime? endDate,
    int? khatamTimes,
    bool? spreadRemainder,
    KhatamMode? mode,
    List<String>? prayerSlots,
    Map<int, bool>? doneDays,
    Map<String, bool>? doneSlots,
  }) {
    return KhatamPlannerState(
      unit: unit ?? this.unit,
      totalPages: totalPages ?? this.totalPages,
      totalAyat: totalAyat ?? this.totalAyat,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      khatamTimes: khatamTimes ?? this.khatamTimes,
      spreadRemainder: spreadRemainder ?? this.spreadRemainder,
      mode: mode ?? this.mode,
      prayerSlots: prayerSlots ?? this.prayerSlots,
      doneDays: doneDays ?? this.doneDays,
      doneSlots: doneSlots ?? this.doneSlots,
    );
  }

  static int _safeInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
  }

  static int _ceilDiv(int a, int b) => (a + b - 1) ~/ b;

  static int _min(int a, int b) => a < b ? a : b;
}
