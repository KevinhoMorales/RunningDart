import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:running_dart/models/membership_modality.dart';
import 'package:running_dart/models/membership_status.dart';
import 'package:running_dart/models/user_model.dart';
import 'package:running_dart/models/user_role.dart';
import 'package:running_dart/providers/auth_provider.dart';
import 'package:running_dart/services/auth_service.dart';
import 'package:running_dart/services/local_storage_service.dart';
import 'package:running_dart/services/mock_auth_service.dart';

void main() {
  // AuthProvider crea WatchSyncService, que registra un MethodChannel y
  // necesita el binding inicializado.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MockAuthService.deleteAccount removes user and clears session', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageService(prefs);
    final authService = MockAuthService(storage);

    final user = UserModel(
      id: 'user-1',
      email: 'member@test.com',
      displayName: 'Member Test',
      qrCode: 'RD-test',
      createdAt: DateTime(2026, 1, 1),
      isActive: true,
      role: UserRole.member,
      password: 'secret',
      membershipModality: MembershipModality.community,
      membershipStatus: MembershipStatus.active,
    );

    await storage.saveUser(user);
    await storage.setCurrentUserId(user.id);

    await authService.deleteAccount();

    expect(await storage.getCurrentUser(), isNull);
    expect(await storage.getUserByEmail(user.email), isNull);
  });

  test('AuthProvider.deleteAccount clears current user', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageService(prefs);
    final authService = MockAuthService(storage);
    final authProvider = AuthProvider(authService);

    final user = UserModel(
      id: 'user-2',
      email: 'delete@test.com',
      displayName: 'Delete Me',
      qrCode: 'RD-delete',
      createdAt: DateTime(2026, 1, 1),
      isActive: true,
      role: UserRole.member,
      password: 'secret',
      membershipModality: MembershipModality.community,
      membershipStatus: MembershipStatus.active,
    );

    await storage.saveUser(user);
    await storage.setCurrentUserId(user.id);
    await authProvider.initialize();

    final success = await authProvider.deleteAccount();

    expect(success, isTrue);
    expect(authProvider.user, isNull);
    expect(authProvider.hasSession, isFalse);
  });

  test('MockAuthService.deleteAccount without session throws AuthException', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageService(prefs);
    final authService = MockAuthService(storage);

    expect(
      authService.deleteAccount(),
      throwsA(isA<AuthException>()),
    );
  });

  group('reauthenticate', () {
    Future<MockAuthService> signedInService() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);

      final user = UserModel(
        id: 'user-3',
        email: 'reauth@test.com',
        displayName: 'Reauth Test',
        qrCode: 'RD-reauth',
        createdAt: DateTime(2026, 1, 1),
        isActive: true,
        role: UserRole.member,
        password: 'secret',
        membershipModality: MembershipModality.community,
        membershipStatus: MembershipStatus.active,
      );

      await storage.saveUser(user);
      await storage.setCurrentUserId(user.id);
      return MockAuthService(storage);
    }

    test('accepts the current password', () async {
      final authService = await signedInService();

      await expectLater(authService.reauthenticate('secret'), completes);
    });

    test('rejects a wrong password', () async {
      final authService = await signedInService();

      await expectLater(
        authService.reauthenticate('not-my-password'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'La contraseña no es correcta.',
          ),
        ),
      );
    });

    test('rejects when there is no session', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final authService = MockAuthService(LocalStorageService(prefs));

      await expectLater(
        authService.reauthenticate('secret'),
        throwsA(isA<AuthException>()),
      );
    });
  });
}
