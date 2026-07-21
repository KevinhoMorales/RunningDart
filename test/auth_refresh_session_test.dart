import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_dart/models/membership_modality.dart';
import 'package:running_dart/models/membership_status.dart';
import 'package:running_dart/models/user_model.dart';
import 'package:running_dart/models/user_role.dart';
import 'package:running_dart/providers/auth_provider.dart';
import 'package:running_dart/services/auth_service.dart';

class _RefreshSessionAuthService implements AuthService {
  _RefreshSessionAuthService(this._resolvedUser);

  final UserModel? _resolvedUser;
  var resolveStartupSessionCalls = 0;
  final _controller = StreamController<UserModel?>.broadcast();

  @override
  Stream<UserModel?> get userChanges => _controller.stream;

  @override
  Future<UserModel?> getCurrentUser() async => _resolvedUser;

  @override
  Future<UserModel?> resolveStartupSession() async {
    resolveStartupSessionCalls++;
    return _resolvedUser;
  }

  @override
  Future<UserModel?> refreshCurrentUser() => resolveStartupSession();

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
  Future<void> deleteAccount() async {}
}

UserModel _sampleUser() {
  return UserModel(
    id: 'refresh-user',
    email: 'refresh@test.com',
    displayName: 'Refresh User',
    qrCode: 'RD-refresh',
    createdAt: DateTime(2026, 1, 1),
    isActive: true,
    role: UserRole.member,
    membershipModality: MembershipModality.community,
    membershipStatus: MembershipStatus.active,
  );
}

void main() {
  test('refreshAccountStatus uses resolveStartupSession rules', () async {
    final service = _RefreshSessionAuthService(_sampleUser());
    final provider = AuthProvider(service);

    await provider.refreshAccountStatus();

    expect(service.resolveStartupSessionCalls, 1);
    expect(provider.user, isNotNull);
  });

  test('refreshAccountStatus clears user when startup resolves no profile', () async {
    final service = _RefreshSessionAuthService(null);
    final provider = AuthProvider(service);

    await provider.refreshAccountStatus();

    expect(service.resolveStartupSessionCalls, 1);
    expect(provider.user, isNull);
    expect(provider.hasSession, isFalse);
  });
}
