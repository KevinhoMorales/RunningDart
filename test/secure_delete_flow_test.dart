import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

import 'package:running_dart/services/biometric_auth_service.dart';
import 'package:running_dart/utils/secure_delete_flow.dart';

void main() {
  group('BiometricAuthService.biometricLabel', () {
    final service = BiometricAuthService();

    test('prefers Face ID label', () {
      expect(
        service.biometricLabel([BiometricType.face]),
        'Face ID',
      );
    });

    test('uses fingerprint label when available', () {
      expect(
        service.biometricLabel([BiometricType.fingerprint]),
        'huella dactilar',
      );
    });
  });

  group('SecureDeleteResult.userMessage', () {
    test('returns messages only for biometric failures', () {
      expect(SecureDeleteResult.approved.userMessage, isNull);
      expect(SecureDeleteResult.cancelled.userMessage, isNull);
      expect(
        SecureDeleteResult.biometricFailed.userMessage,
        isNotNull,
      );
      expect(
        SecureDeleteResult.biometricUnavailable.userMessage,
        isNotNull,
      );
    });
  });
}
