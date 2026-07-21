import 'package:flutter/material.dart';

class ScheduleHelpers {
  ScheduleHelpers._();

  static IconData iconFor(String? iconName) {
    return switch (iconName) {
      'groups' => Icons.groups_rounded,
      'fitness' => Icons.fitness_center_rounded,
      'community' => Icons.directions_run_rounded,
      _ => Icons.schedule_rounded,
    };
  }

  static ScheduleLineDisplay parseLine(String line) {
    final trimmed = line.trim();
    if (trimmed.contains(' · ')) {
      final parts = trimmed.split(' · ');
      return ScheduleLineDisplay(
        primary: parts.first.trim(),
        secondary: parts.sublist(1).join(' · ').trim(),
        isTimeSlot: _looksLikeSchedule(parts.first),
      );
    }
    return ScheduleLineDisplay(
      primary: trimmed,
      isTimeSlot: false,
      isLocation: _looksLikeLocation(trimmed),
    );
  }

  static bool _looksLikeSchedule(String value) {
    final lower = value.toLowerCase();
    return lower.contains('lunes') ||
        lower.contains('martes') ||
        lower.contains('miércoles') ||
        lower.contains('miercoles') ||
        lower.contains('jueves') ||
        lower.contains('viernes') ||
        lower.contains('sábado') ||
        lower.contains('sabado') ||
        lower.contains('domingo') ||
        lower.contains('fin de semana');
  }

  static bool _looksLikeLocation(String value) {
    final lower = value.toLowerCase();
    return lower.contains('tenka') ||
        lower.contains('parque') ||
        lower.contains('gym') ||
        lower.contains('sede');
  }
}

class ScheduleLineDisplay {
  const ScheduleLineDisplay({
    required this.primary,
    this.secondary,
    this.isTimeSlot = false,
    this.isLocation = false,
  });

  final String primary;
  final String? secondary;
  final bool isTimeSlot;
  final bool isLocation;
}
