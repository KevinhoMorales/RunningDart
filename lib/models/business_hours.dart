import 'package:flutter/material.dart';

enum BusinessDayPeriod {
  morning,
  afternoon;

  String get firestoreValue => name;

  String get displayName => switch (this) {
        BusinessDayPeriod.morning => 'Mañana',
        BusinessDayPeriod.afternoon => 'Tarde',
      };

  static BusinessDayPeriod fromFirestore(String? value) {
    return value == 'afternoon'
        ? BusinessDayPeriod.afternoon
        : BusinessDayPeriod.morning;
  }
}

class BusinessHoursSlot {
  const BusinessHoursSlot({
    required this.weekdays,
    required this.period,
    required this.start,
    required this.end,
  });

  final List<int> weekdays;
  final BusinessDayPeriod period;
  final TimeOfDay start;
  final TimeOfDay end;

  Map<String, dynamic> toJson() {
    return {
      'weekdays': weekdays,
      'period': period.firestoreValue,
      'start': _formatTime(start),
      'end': _formatTime(end),
    };
  }

  factory BusinessHoursSlot.fromJson(Map<String, dynamic> json) {
    return BusinessHoursSlot(
      weekdays: (json['weekdays'] as List<dynamic>? ?? [])
          .map((day) => (day as num).toInt())
          .where((day) => day >= 1 && day <= 7)
          .toList()
        ..sort(),
      period: BusinessDayPeriod.fromFirestore(json['period'] as String?),
      start: _parseTime(json['start'] as String?),
      end: _parseTime(json['end'] as String?),
    );
  }

  BusinessHoursSlot copyWith({
    List<int>? weekdays,
    BusinessDayPeriod? period,
    TimeOfDay? start,
    TimeOfDay? end,
  }) {
    return BusinessHoursSlot(
      weekdays: weekdays ?? this.weekdays,
      period: period ?? this.period,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  static String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  static TimeOfDay _parseTime(String? value) {
    if (value == null || !value.contains(':')) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
    final parts = value.split(':');
    final hour = int.tryParse(parts.first) ?? 9;
    final minute = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }
}

class BusinessOperatingHours {
  const BusinessOperatingHours({this.slots = const []});

  static const empty = BusinessOperatingHours();

  final List<BusinessHoursSlot> slots;

  bool get isEmpty => slots.isEmpty;
  bool get isNotEmpty => slots.isNotEmpty;

  List<Map<String, dynamic>> toJsonList() {
    return slots.map((slot) => slot.toJson()).toList();
  }

  factory BusinessOperatingHours.fromJsonList(List<dynamic>? value) {
    if (value == null || value.isEmpty) {
      return BusinessOperatingHours.empty;
    }

    final slots = value
        .whereType<Map>()
        .map((item) => BusinessHoursSlot.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);

    return BusinessOperatingHours(slots: slots);
  }

  BusinessOperatingHours copyWith({List<BusinessHoursSlot>? slots}) {
    return BusinessOperatingHours(slots: slots ?? this.slots);
  }
}
