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
}
