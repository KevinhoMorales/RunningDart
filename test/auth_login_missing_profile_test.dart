import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_dart/providers/auth_provider.dart';
import 'package:running_dart/services/auth_service.dart';
import 'package:running_dart/models/user_model.dart';

class _LoginMissingProfileAuthService implements AuthService {
  final _controller = StreamController<UserModel?>.broadcast();

  @override
  Stream<UserModel?> get userChanges => _controller.stream;

  @override
  Future<UserModel?> getCurrentUser() async => null;

  @override
  Future<UserModel?> resolveStartupSession() async => null;

  @override
  Future<UserModel?> refreshCurrentUser() => resolveStartupSession();

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    throw AuthException(
      'Tu perfil no está disponible en Desarrollo. '
      'Regístrate en esta app para crear tu perfil.',
    );
  }

  @override
  Future<UserModel> register({
    required String email,
    required String password,
    required RegisterProfileData profile,
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

void main() {
  test('login without Firestore profile returns false and surfaces error', () async {
    final service = _LoginMissingProfileAuthService();
    final provider = AuthProvider(service);

    final success = await provider.login(
      email: 'user@test.com',
      password: 'secret123',
    );

    expect(success, isFalse);
    expect(provider.user, isNull);
    expect(provider.error, contains('Regístrate en esta app'));
  });
}
