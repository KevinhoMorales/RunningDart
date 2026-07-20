import 'package:local_auth/local_auth.dart';

class BiometricAuthException implements Exception {
  BiometricAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BiometricAuthService {
  BiometricAuthService({LocalAuthentication? localAuth})
      : _localAuth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  Future<bool> canAuthenticate() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      if (!isSupported) {
        return false;
      }
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      return canCheckBiometrics || isSupported;
    } catch (_) {
      return false;
    }
  }

  Future<List<BiometricType>> availableBiometrics() async {
    try {
      return _localAuth.getAvailableBiometrics();
    } catch (_) {
      return const [];
    }
  }

  String biometricLabel(List<BiometricType> types) {
    if (types.contains(BiometricType.face)) {
      return 'Face ID';
    }
    if (types.contains(BiometricType.strong) ||
        types.contains(BiometricType.fingerprint)) {
      return 'huella dactilar';
    }
    if (types.contains(BiometricType.weak)) {
      return 'biometría del dispositivo';
    }
    return 'Face ID o huella';
  }

  Future<bool> authenticate({required String reason}) async {
    try {
      return _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (_) {
      throw BiometricAuthException(
        'No se pudo verificar tu identidad. Intenta de nuevo.',
      );
    }
  }
}
