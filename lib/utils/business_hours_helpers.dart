import 'package:flutter/material.dart';

import '../models/business_hours.dart';

class BusinessHoursHelpers {
  BusinessHoursHelpers._();

  static const weekdayShortLabels = {
    1: 'Lun',
    2: 'Mar',
    3: 'Mié',
    4: 'Jue',
    5: 'Vie',
    6: 'Sáb',
    7: 'Dom',
  };

  static const weekdayLetters = {
    1: 'L',
    2: 'M',
    3: 'X',
    4: 'J',
    5: 'V',
    6: 'S',
    7: 'D',
  };

  static const weekdaysPresetWeekdays = [1, 2, 3, 4, 5];
  static const weekdaysPresetWeekend = [6, 7];
  static const weekdaysPresetAll = [1, 2, 3, 4, 5, 6, 7];

  static String periodLabel(BusinessDayPeriod period) => period.displayName;

  static String formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.period == DayPeriod.am ? 'a.m.' : 'p.m.';
    return '$hour:$minute $suffix';
  }

  static String formatWeekdays(List<int> weekdays) {
    if (weekdays.isEmpty) {
      return 'Sin días';
    }

    final sorted = weekdays.toList()..sort();
    if (sorted.length == 7) {
      return 'Todos los días';
    }

    final runs = <List<int>>[];
    var current = <int>[sorted.first];

    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i] == current.last + 1) {
        current.add(sorted[i]);
      } else {
        runs.add(current);
        current = [sorted[i]];
      }
    }
    runs.add(current);

    return runs.map((run) {
      if (run.length == 1) {
        return weekdayShortLabels[run.first]!;
      }
      return '${weekdayShortLabels[run.first]} - ${weekdayShortLabels[run.last]}';
    }).join(', ');
  }

  static String formatSlot(BusinessHoursSlot slot) {
    return '${formatWeekdays(slot.weekdays)} · ${periodLabel(slot.period)} · '
        '${formatTime(slot.start)} - ${formatTime(slot.end)}';
  }

  static String toDisplaySummary(List<BusinessHoursSlot> slots) {
    if (slots.isEmpty) {
      return '';
    }

    return sortedSlots(slots).map(formatSlot).join(' | ');
  }

  static List<BusinessHoursSlot> sortedSlots(List<BusinessHoursSlot> slots) {
    final copy = List<BusinessHoursSlot>.from(slots);
    copy.sort((a, b) {
      final dayCompare = (a.weekdays.isEmpty ? 8 : a.weekdays.first)
          .compareTo(b.weekdays.isEmpty ? 8 : b.weekdays.first);
      if (dayCompare != 0) {
        return dayCompare;
      }
      final periodCompare = a.period.index.compareTo(b.period.index);
      if (periodCompare != 0) {
        return periodCompare;
      }
      return _minutes(a.start).compareTo(_minutes(b.start));
    });
    return copy;
  }

  static int _minutes(TimeOfDay time) => time.hour * 60 + time.minute;

  static bool isValidTimeRange(TimeOfDay start, TimeOfDay end) {
    return _minutes(start) < _minutes(end);
  }

  static IconData iconForPeriod(BusinessDayPeriod period) {
    return switch (period) {
      BusinessDayPeriod.morning => Icons.wb_sunny_outlined,
      BusinessDayPeriod.afternoon => Icons.wb_twilight_rounded,
      BusinessDayPeriod.night => Icons.nightlight_round,
    };
  }

  static BusinessHoursSlot defaultSlotForPeriod(
    BusinessDayPeriod period, {
    List<int> weekdays = weekdaysPresetWeekdays,
  }) {
    final sortedWeekdays = weekdays.toList()..sort();
    return switch (period) {
      BusinessDayPeriod.morning => BusinessHoursSlot(
          weekdays: sortedWeekdays,
          period: period,
          start: const TimeOfDay(hour: 9, minute: 0),
          end: const TimeOfDay(hour: 12, minute: 0),
        ),
      BusinessDayPeriod.afternoon => BusinessHoursSlot(
          weekdays: sortedWeekdays,
          period: period,
          start: const TimeOfDay(hour: 14, minute: 0),
          end: const TimeOfDay(hour: 20, minute: 0),
        ),
      BusinessDayPeriod.night => BusinessHoursSlot(
          weekdays: sortedWeekdays,
          period: period,
          start: const TimeOfDay(hour: 19, minute: 0),
          end: const TimeOfDay(hour: 23, minute: 0),
        ),
    };
  }

  static String formatSlotPeriodAndTime(BusinessHoursSlot slot) {
    return '${periodLabel(slot.period)} · '
        '${formatTime(slot.start)} - ${formatTime(slot.end)}';
  }

  static List<BusinessHoursSlotGroup> groupSlotsByWeekdays(
    List<BusinessHoursSlot> slots,
  ) {
    final groups = <String, List<BusinessHoursSlot>>{};

    for (final slot in slots) {
      final key = slot.weekdays.join(',');
      groups.putIfAbsent(key, () => []).add(slot);
    }

    final grouped = groups.entries.map((entry) {
      return BusinessHoursSlotGroup(
        weekdays: entry.value.first.weekdays,
        slots: sortedSlots(entry.value),
      );
    }).toList();

    grouped.sort((a, b) {
      final dayCompare = (a.weekdays.isEmpty ? 8 : a.weekdays.first)
          .compareTo(b.weekdays.isEmpty ? 8 : b.weekdays.first);
      if (dayCompare != 0) {
        return dayCompare;
      }
      return a.weekdays.length.compareTo(b.weekdays.length);
    });

    return grouped;
  }

  static String? validateSlots(List<BusinessHoursSlot> slots) {
    if (slots.isEmpty) {
      return 'Agrega al menos un horario.';
    }

    final seen = <String>{};

    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      if (slot.weekdays.isEmpty) {
        return 'Selecciona al menos un día en el horario ${i + 1}.';
      }
      if (!isValidTimeRange(slot.start, slot.end)) {
        return 'La hora de fin debe ser posterior al inicio en el horario ${i + 1}.';
      }

      for (final day in slot.weekdays) {
        final key = '$day:${slot.period.firestoreValue}';
        if (seen.contains(key)) {
          return 'Ya existe ${periodLabel(slot.period).toLowerCase()} para '
              '${weekdayShortLabels[day]}. Revisa los bloques duplicados.';
        }
        seen.add(key);
      }
    }

    return null;
  }
}

class BusinessHoursSlotGroup {
  const BusinessHoursSlotGroup({
    required this.weekdays,
    required this.slots,
  });

  final List<int> weekdays;
  final List<BusinessHoursSlot> slots;
}
