import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_dart/models/membership_modality.dart';
import 'package:running_dart/models/membership_status.dart';
import 'package:running_dart/models/user_model.dart';
import 'package:running_dart/models/user_role.dart';
import 'package:running_dart/providers/auth_provider.dart';
import 'package:running_dart/services/auth_service.dart';

class _StartupAuthService implements AuthService {
  _StartupAuthService(this._resolvedUser);

  final UserModel? _resolvedUser;
  final _controller = StreamController<UserModel?>.broadcast();

  @override
  Stream<UserModel?> get userChanges => _controller.stream;

  @override
  Future<UserModel?> getCurrentUser() async => _resolvedUser;

  @override
  Future<UserModel?> resolveStartupSession() async => _resolvedUser;

  @override
  Future<UserModel?> refreshCurrentUser() async => _resolvedUser;

  @override
  Future<UserModel> register({
    required String email,
    required String password,
    required RegisterProfileData profile,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> reauthenticate(String password) async {}

  @override
  Future<void> deleteAccount() async {}
}

UserModel _sampleUser() {
  return UserModel(
    id: 'user-startup',
    email: 'startup@test.com',
    displayName: 'Startup User',
    qrCode: 'RD-startup',
    createdAt: DateTime(2026, 1, 1),
    isActive: true,
    role: UserRole.member,
    membershipModality: MembershipModality.community,
    membershipStatus: MembershipStatus.active,
  );
}

void main() {
  test('initialize restores session when startup resolves a user', () async {
    final provider = AuthProvider(_StartupAuthService(_sampleUser()));

    await provider.initialize();

    expect(provider.user, isNotNull);
    expect(provider.hasSession, isTrue);
    expect(provider.postAuthRoute, '/home');
  });

  test('initialize leaves user null when startup resolves no profile', () async {
    final provider = AuthProvider(_StartupAuthService(null));

    await provider.initialize();

    expect(provider.user, isNull);
    expect(provider.hasSession, isFalse);
    expect(provider.postAuthRoute, '/login');
  });
}
