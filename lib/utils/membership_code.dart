/// Utilidades para el identificador unico de membresia (`qrCode`).
///
/// El codigo tiene el formato `RD-<uuid v4>` (por ejemplo
/// `RD-550e8400-e29b-41d4-a716-446655440000`). El cuerpo del uuid se genera
/// siempre en minusculas (ver `firebase_auth_service.dart` /
/// `mock_auth_service.dart`), por lo que la forma canonica es el prefijo
/// `RD-` en mayusculas seguido del uuid en minusculas.
///
/// Estas utilidades normalizan, validan y presentan ese mismo identificador
/// tanto en el escaneo como en el ingreso manual, garantizando una unica
/// fuente de verdad y que la comparacion contra Firestore (sensible a
/// mayusculas/minusculas) coincida siempre con el valor almacenado.
class MembershipCode {
  const MembershipCode._();

  static const String prefix = 'RD-';

  /// Cuerpo permitido tras normalizar: hex en minusculas y guiones.
  static final RegExp _bodyPattern = RegExp(r'^[0-9a-f-]+$');

  /// Longitud minima razonable del codigo normalizado (`RD-` + cuerpo).
  static const int _minLength = 8;

  /// Normaliza la entrada a la forma canonica que se almacena en Firestore:
  /// recorta, elimina espacios, deja el prefijo `RD-` en mayusculas y el
  /// cuerpo del uuid en minusculas. Asi copiar/pegar o teclear con distinta
  /// capitalizacion sigue coincidiendo con el valor guardado.
  static String normalize(String input) {
    final trimmed = input.trim().replaceAll(RegExp(r'\s+'), '');
    if (trimmed.length >= prefix.length &&
        trimmed.substring(0, prefix.length).toUpperCase() == prefix) {
      return prefix + trimmed.substring(prefix.length).toLowerCase();
    }
    return trimmed;
  }

  /// Valida que el codigo tenga el formato esperado. Es intencionalmente
  /// permisivo: la verdad final (existe / no existe) la resuelve Firestore.
  static bool isValid(String input) {
    final normalized = normalize(input);
    if (normalized.length < _minLength) {
      return false;
    }
    if (!normalized.startsWith(prefix)) {
      return false;
    }
    final body = normalized.substring(prefix.length);
    if (!_bodyPattern.hasMatch(body)) {
      return false;
    }
    // El cuerpo (sin guiones) debe tener contenido real.
    return body.replaceAll('-', '').isNotEmpty;
  }

  /// Devuelve el codigo listo para mostrarse. Se presenta exactamente en su
  /// forma canonica (igual al valor que utiliza el escaner), ya agrupado por
  /// los guiones del uuid.
  static String formatForDisplay(String code) {
    return normalize(code);
  }
}
