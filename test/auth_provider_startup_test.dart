import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:running_dart/models/user_model.dart';
import 'package:running_dart/providers/auth_provider.dart';
import 'package:running_dart/services/auth_service.dart';

class _ThrowingAuthService implements AuthService {
  @override
  Stream<UserModel?> get userChanges => const Stream.empty();

  @override
  Future<UserModel?> getCurrentUser() {
    throw Exception('Firestore unavailable');
  }

  @override
  Future<UserModel?> resolveStartupSession() {
    throw Exception('Firestore unavailable');
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
  Future<void> reauthenticate(String password) async {}

  @override
  Future<void> deleteAccount() async {}
}

void main() {
  test('initialize keeps user null and sets error when resolveStartupSession fails', () async {
    final provider = AuthProvider(_ThrowingAuthService());

    await provider.initialize();

    expect(provider.user, isNull);
    expect(provider.hasSession, isFalse);
    expect(provider.error, isNotNull);
    expect(provider.isLoading, isFalse);
  });
}
