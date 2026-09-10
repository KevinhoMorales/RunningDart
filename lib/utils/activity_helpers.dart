import '../models/activity_model.dart';
import '../models/activity_type.dart';
import '../utils/constants.dart';

/// Helpers de fechas para Social Runs (martes/jueves 19:00 América/Guayaquil).
abstract final class ActivityHelpers {
  /// Ecuador (Santo Domingo) no usa DST: UTC-5 fijo.
  static const Duration ecuadorOffset = Duration(hours: -5);

  static DateTime ecuadorNow([DateTime? utcNow]) {
    final now = utcNow ?? DateTime.now().toUtc();
    return now.add(ecuadorOffset);
  }

  /// 19:00 hora Ecuador del día civil [year]-[month]-[day].
  static DateTime socialRunStartAt({
    required int year,
    required int month,
    required int day,
  }) {
    final ecuadorLocal = DateTime(year, month, day, 19);
    return ecuadorLocal.subtract(ecuadorOffset).toUtc();
  }

  static DateTime defaultEndsAt(DateTime startsAt) {
    return startsAt.add(const Duration(hours: 2));
  }

  static DateTime defaultCheckInOpensAt(DateTime startsAt) {
    return startsAt.subtract(const Duration(minutes: 30));
  }

  static DateTime defaultCheckInClosesAt(DateTime startsAt) {
    return startsAt.add(const Duration(hours: 2));
  }

  /// Clave ISO semana + día para generación idempotente.
  /// Ej: `social_run_2026-W37-tue`
  static String socialRunRecurrenceKey(DateTime ecuadorDay) {
    final iso = _isoWeek(ecuadorDay);
    final weekday = ecuadorDay.weekday; // 1=Mon … 7=Sun
    final dayKey = switch (weekday) {
      DateTime.tuesday => 'tue',
      DateTime.thursday => 'thu',
      _ => 'd$weekday',
    };
    return 'social_run_${iso.year}-W${iso.week.toString().padLeft(2, '0')}-$dayKey';
  }

  static ({int year, int week}) _isoWeek(DateTime date) {
    final day = DateTime.utc(date.year, date.month, date.day);
    // Thursday of current week determines ISO year.
    final thursday = day.add(Duration(days: 4 - day.weekday));
    final firstThursday = DateTime.utc(thursday.year, 1, 4);
    final week1Thursday = firstThursday.add(
      Duration(days: 4 - firstThursday.weekday),
    );
    final week = 1 + thursday.difference(week1Thursday).inDays ~/ 7;
    return (year: thursday.year, week: week);
  }

  /// Próximos [weeksAhead] martes y jueves a partir de hoy (Ecuador).
  static List<DateTime> upcomingSocialRunDays({
    int weeksAhead = 4,
    DateTime? now,
  }) {
    final ecuador = ecuadorNow(now?.toUtc());
    final startDay = DateTime(ecuador.year, ecuador.month, ecuador.day);
    final end = startDay.add(Duration(days: weeksAhead * 7));
    final days = <DateTime>[];

    for (var cursor = startDay;
        !cursor.isAfter(end);
        cursor = cursor.add(const Duration(days: 1))) {
      if (cursor.weekday == DateTime.tuesday ||
          cursor.weekday == DateTime.thursday) {
        // Si ya pasó la hora de hoy, no incluir el día de hoy.
        if (cursor.year == ecuador.year &&
            cursor.month == ecuador.month &&
            cursor.day == ecuador.day &&
            ecuador.hour >= 21) {
          continue;
        }
        days.add(cursor);
      }
    }
    return days;
  }

  static ActivityModel buildSocialRun({
    required DateTime ecuadorDay,
    required DateTime now,
    String? createdBy,
    String? id,
  }) {
    final startsAt = socialRunStartAt(
      year: ecuadorDay.year,
      month: ecuadorDay.month,
      day: ecuadorDay.day,
    );
    return ActivityModel(
      id: id ?? '',
      title: 'Social Run',
      type: ActivityType.socialRun,
      startsAt: startsAt,
      endsAt: defaultEndsAt(startsAt),
      venue: AppConstants.clubVenue,
      location: AppConstants.clubLocation,
      description:
          'Entrenamiento presencial de la comunidad SAINTS. Martes y jueves.',
      isPublished: true,
      checkInEnabled: false,
      confirmedCount: 0,
      checkedInCount: 0,
      recurrenceKey: socialRunRecurrenceKey(ecuadorDay),
      createdBy: createdBy,
      createdAt: now,
      updatedAt: now,
    );
  }

  static String formatActivityWhen(DateTime startsAt) {
    final ecuador = startsAt.toUtc().add(ecuadorOffset);
    const weekdays = {
      DateTime.monday: 'Lunes',
      DateTime.tuesday: 'Martes',
      DateTime.wednesday: 'Miércoles',
      DateTime.thursday: 'Jueves',
      DateTime.friday: 'Viernes',
      DateTime.saturday: 'Sábado',
      DateTime.sunday: 'Domingo',
    };
    final weekday = weekdays[ecuador.weekday] ?? '';
    final day = ecuador.day.toString().padLeft(2, '0');
    final month = ecuador.month.toString().padLeft(2, '0');
    final hour = ecuador.hour.toString().padLeft(2, '0');
    final minute = ecuador.minute.toString().padLeft(2, '0');
    return '$weekday $day/$month · $hour:$minute';
  }
}
