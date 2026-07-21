class Helpers {
  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static int daysUntilEvent(DateTime eventDate, [DateTime? now]) {
    final today = startOfDay(now ?? DateTime.now());
    final eventDay = startOfDay(eventDate);
    return eventDay.difference(today).inDays;
  }

  static bool isEventPast(DateTime eventDate, [DateTime? now]) {
    return daysUntilEvent(eventDate, now) < 0;
  }

  static bool isEventUpcoming(DateTime eventDate, [DateTime? now]) {
    return !isEventPast(eventDate, now);
  }

  static String eventStatusLabel(DateTime eventDate, [DateTime? now]) {
    final days = daysUntilEvent(eventDate, now);

    if (days < 0) {
      return 'Finalizado';
    }
    if (days == 0) {
      return 'Hoy';
    }
    if (days == 1) {
      return 'Mañana';
    }
    if (days <= 6) {
      return 'En $days días';
    }
    if (days <= 13) {
      return 'En 1 semana';
    }

    final weeks = ((days - 14) ~/ 7) + 2;
    return 'En $weeks semanas';
  }

  static bool eventStatusIsUrgent(DateTime eventDate, [DateTime? now]) {
    final days = daysUntilEvent(eventDate, now);
    return days >= 0 && days <= 1;
  }

  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  static bool isRestaurantCategory(String category) {
    return category == 'restaurante';
  }

  static bool isValidHttpUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return false;
    }

    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  static String categoryLabel(String category) {
    switch (category) {
      case 'café':
        return 'Café';
      case 'restaurante':
        return 'Restaurante';
      case 'gimnasio':
        return 'Gimnasio';
      case 'retail':
        return 'Retail';
      case 'salud':
        return 'Salud';
      case 'lifestyle':
        return 'Lifestyle';
      case 'servicios':
        return 'Servicios';
      default:
        return category;
    }
  }

  static String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    return '$day/$month/$year';
  }

  /// Saludo según la hora local: 5–11 h, 12–18 h, resto noche.
  static String timeOfDayGreeting([DateTime? now]) {
    final hour = (now ?? DateTime.now()).hour;

    if (hour >= 5 && hour < 12) {
      return 'Buenos días';
    }
    if (hour >= 12 && hour < 19) {
      return 'Buenas tardes';
    }
    return 'Buenas noches';
  }

  static String firstName(String displayName) {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      return 'Usuario';
    }
    return trimmed.split(RegExp(r'\s+')).first;
  }

  static String greetingForUser(String displayName, [DateTime? now]) {
    return '${timeOfDayGreeting(now)}, ${firstName(displayName)}';
  }

  static String formatDiscountLabel(String discount) {
    final value = discount.trim();
    if (value.isEmpty) {
      return value;
    }
    if (value.contains('%')) {
      return value;
    }
    if (RegExp(r'^\d+$').hasMatch(value)) {
      return '$value%';
    }
    return value;
  }

  static String? discountPercentFigure(String discount) {
    final value = discount.trim();
    if (value.isEmpty) {
      return null;
    }

    final match = RegExp(r'(\d+)').firstMatch(value);
    return match?.group(1);
  }

  static bool discountLooksLikePercent(String discount) {
    final value = discount.trim();
    return RegExp(r'^\d+\s*%?$').hasMatch(value);
  }
}
