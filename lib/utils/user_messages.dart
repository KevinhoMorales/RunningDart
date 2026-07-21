import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Mensajes visibles para el usuario, siempre en español.
abstract final class UserMessages {
  static const unexpectedError =
      'Ocurrió un error inesperado. Intenta de nuevo.';

  static String auth(FirebaseAuthException exception) {
    return switch (exception.code) {
      'email-already-in-use' => 'Ya existe una cuenta con este correo.',
      'invalid-email' => 'Ingresa un correo válido.',
      'weak-password' => 'La contraseña debe tener al menos 6 caracteres.',
      'not-found' ||
      'user-not-found' ||
      'invalid-credential' ||
      'invalid-login-credentials' ||
      'wrong-password' =>
        'Correo o contraseña incorrectos.',
      'user-disabled' => 'Esta cuenta ha sido deshabilitada.',
      'too-many-requests' =>
        'Demasiados intentos. Espera un momento e intenta de nuevo.',
      'network-request-failed' =>
        'Sin conexión. Revisa tu internet e intenta de nuevo.',
      'internal-error' => 'Error del servidor. Intenta más tarde.',
      'operation-not-allowed' =>
        'Este método de acceso no está habilitado. Contacta a SAINTS.',
      'requires-recent-login' =>
        'Por seguridad, vuelve a iniciar sesión antes de continuar.',
      'account-exists-with-different-credential' =>
        'Ya existe una cuenta con este correo usando otro método de acceso.',
      'credential-already-in-use' =>
        'Estas credenciales ya están vinculadas a otra cuenta.',
      _ => errorFromRaw(
            exception.message,
            fallback: unexpectedError,
          ),
    };
  }

  static String firestore(FirebaseException exception) {
    return switch (exception.code) {
      'permission-denied' =>
        'No tienes permisos para completar esta acción.',
      'not-found' => 'No se encontró la información solicitada.',
      'unavailable' =>
        'El servicio no está disponible. Intenta más tarde.',
      'deadline-exceeded' =>
        'La operación tardó demasiado. Intenta de nuevo.',
      'resource-exhausted' =>
        'Demasiadas solicitudes. Espera un momento e intenta de nuevo.',
      'unauthenticated' => 'Debes iniciar sesión para continuar.',
      _ => errorFromRaw(
            exception.message,
            fallback: unexpectedError,
          ),
    };
  }

  static String functions(FirebaseFunctionsException exception) {
    return switch (exception.code) {
      'unauthenticated' => 'Debes iniciar sesión para continuar.',
      'failed-precondition' =>
        'No se pudo verificar tu cuenta. Intenta de nuevo.',
      'unavailable' =>
        'El servicio no está disponible. Intenta más tarde.',
      'not-found' => 'No se encontró la información solicitada.',
      'permission-denied' =>
        'No tienes permisos para completar esta acción.',
      'deadline-exceeded' =>
        'La operación tardó demasiado. Intenta de nuevo.',
      _ => errorFromRaw(
            exception.message,
            fallback: 'No se pudo completar la acción. Intenta de nuevo.',
          ),
    };
  }

  static String storage(FirebaseException exception) {
    return switch (exception.code) {
      'unauthorized' || 'permission-denied' =>
        'No tienes permisos para subir esta foto.',
      'object-not-found' => 'No se encontró la imagen seleccionada.',
      'canceled' => 'La subida fue cancelada.',
      _ => errorFromRaw(
            exception.message,
            fallback: 'No se pudo subir la foto. Intenta de nuevo.',
          ),
    };
  }

  /// Normaliza mensajes dinámicos antes de mostrarlos en un toast.
  static String errorFromRaw(
    String? message, {
    required String fallback,
  }) {
    if (message == null || message.trim().isEmpty) {
      return fallback;
    }

    if (_looksLikeUserSpanish(message)) {
      return message.trim();
    }

    final normalized = _normalize(message);

    return switch (normalized) {
      'NOT FOUND' => 'No se encontró la información solicitada.',
      'INVALID LOGIN CREDENTIALS' ||
      'INVALID_LOGIN_CREDENTIALS' ||
      'INVALID CREDENTIAL' ||
      'INVALID_CREDENTIAL' ||
      'WRONG PASSWORD' ||
      'WRONG_PASSWORD' ||
      'USER NOT FOUND' ||
      'USER_NOT_FOUND' =>
        'Correo o contraseña incorrectos.',
      'UNAUTHENTICATED' => 'Debes iniciar sesión para continuar.',
      'PERMISSION DENIED' || 'PERMISSION_DENIED' =>
        'No tienes permisos para completar esta acción.',
      'NETWORK ERROR' ||
      'NETWORK_REQUEST_FAILED' ||
      'NETWORK REQUEST FAILED' =>
        'Sin conexión. Revisa tu internet e intenta de nuevo.',
      'TOO MANY REQUESTS' || 'TOO_MANY_REQUESTS' =>
        'Demasiados intentos. Espera un momento e intenta de nuevo.',
      'INTERNAL ERROR' || 'INTERNAL_ERROR' =>
        'Error del servidor. Intenta más tarde.',
      'UNAVAILABLE' =>
        'El servicio no está disponible. Intenta más tarde.',
      _ => _looksLikeTechnicalEnglish(message) ? fallback : message.trim(),
    };
  }

  static String error(String? message, {String? fallback}) {
    return errorFromRaw(
      message,
      fallback: fallback ?? unexpectedError,
    );
  }

  static String _normalize(String message) {
    return message.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
  }

  static bool _looksLikeUserSpanish(String message) {
    return RegExp(r'[áéíóúñÁÉÍÓÚÑ¿¡]').hasMatch(message);
  }

  static bool _looksLikeTechnicalEnglish(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    if (_looksLikeUserSpanish(trimmed)) {
      return false;
    }

    if (RegExp(r'^[A-Z0-9 _\-:]+$').hasMatch(trimmed)) {
      return true;
    }

    return RegExp(
      r'\b(the|is|are|was|were|not found|invalid|error|failed|denied)\b',
      caseSensitive: false,
    ).hasMatch(trimmed);
  }
}
