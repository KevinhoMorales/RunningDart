/// Claves y etiquetas del periodo mensual de la Liga (hora Ecuador).
abstract final class LeagueHelpers {
  static const Duration ecuadorOffset = Duration(hours: -5);

  static const _monthNames = <String>[
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  static DateTime ecuadorNow([DateTime? utcNow]) {
    final now = (utcNow ?? DateTime.now()).toUtc();
    return now.add(ecuadorOffset);
  }

  /// Periodo de ranking: `YYYY-MM` en calendario Ecuador.
  static String currentPeriodKey([DateTime? now]) {
    final ecuador = ecuadorNow(now);
    final month = ecuador.month.toString().padLeft(2, '0');
    return '${ecuador.year}-$month';
  }

  static String periodLabel(String periodKey) {
    final parts = periodKey.split('-');
    if (parts.length != 2) {
      return periodKey;
    }
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) {
      return periodKey;
    }
    return '${_monthNames[month - 1]} $year';
  }

  static String shortPeriodLabel(String periodKey) {
    final parts = periodKey.split('-');
    if (parts.length != 2) {
      return periodKey;
    }
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) {
      return periodKey;
    }
    final short = _monthNames[month - 1].substring(0, 3);
    return '$short $year';
  }

  static String standingDocId(String periodKey, String userId) =>
      '${periodKey}_$userId';
}
