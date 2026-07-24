import 'package:flutter/services.dart';

/// Reglas de formato y disponibilidad temporal para el nombre de usuario.
class UsernameHelpers {
  UsernameHelpers._();

  static const int minLength = 3;
  static const int maxLength = 20;

  /// Días que debe esperar un usuario entre cambios de username.
  static const int cooldownDays = 30;

  static final RegExp _pattern = RegExp(r'^[a-z][a-z0-9._]{2,19}$');

  static String normalize(String value) {
    return value.trim().toLowerCase();
  }

  static bool isValid(String value) {
    final normalized = normalize(value);
    if (!_pattern.hasMatch(normalized)) {
      return false;
    }
    if (normalized.contains('..') || normalized.contains('__')) {
      return false;
    }
    return !normalized.endsWith('.') && !normalized.endsWith('_');
  }

  /// Mensaje de validación para formularios; null cuando el valor es válido.
  static String? validationError(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) {
      return 'Elige un nombre de usuario';
    }
    final normalized = normalize(raw);
    if (normalized.length < minLength) {
      return 'Mínimo $minLength caracteres';
    }
    if (normalized.length > maxLength) {
      return 'Máximo $maxLength caracteres';
    }
    if (!isValid(normalized)) {
      return 'Usa letras, números, punto o guion bajo. Debe empezar con letra.';
    }
    return null;
  }

  static List<TextInputFormatter> get inputFormatters => [
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._]')),
        LengthLimitingTextInputFormatter(maxLength),
      ];

  /// Propone un username a partir del correo, saneando caracteres inválidos.
  ///
  /// El resultado siempre cumple [isValid], así que puede reservarse tal cual.
  static String suggestFromEmail(String email) {
    final localPart = email.split('@').first;
    var suggestion = normalize(localPart)
        .replaceAll(RegExp(r'[^a-z0-9._]'), '')
        // "juan..perez" y "juan__perez" no pasan isValid.
        .replaceAll(RegExp(r'[._]{2,}'), '.')
        .replaceAll(RegExp(r'^[^a-z]+'), '');

    if (suggestion.length > maxLength) {
      suggestion = suggestion.substring(0, maxLength);
    }
    while (suggestion.endsWith('.') || suggestion.endsWith('_')) {
      suggestion = suggestion.substring(0, suggestion.length - 1);
    }
    if (suggestion.isEmpty) {
      return 'saints';
    }
    if (suggestion.length < minLength) {
      suggestion = suggestion.padRight(minLength, '0');
    }
    return suggestion;
  }

  /// Días restantes antes de poder cambiar de nuevo. 0 si ya puede cambiar.
  static int daysUntilChangeAllowed(DateTime? lastChangedAt) {
    if (lastChangedAt == null) {
      return 0;
    }
    final unlockDate = lastChangedAt.add(const Duration(days: cooldownDays));
    final remaining = unlockDate.difference(DateTime.now()).inHours;
    if (remaining <= 0) {
      return 0;
    }
    return (remaining / 24).ceil();
  }

  static bool canChange(DateTime? lastChangedAt) {
    return daysUntilChangeAllowed(lastChangedAt) == 0;
  }
}
