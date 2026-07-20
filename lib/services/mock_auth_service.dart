import 'dart:async';

import 'package:uuid/uuid.dart';

import '../models/user_model.dart';
import '../models/user_role.dart';
import 'auth_service.dart';
import 'local_storage_service.dart';

/// Mock implementation using SharedPreferences.
/// Passwords are stored in plain text for local development only.
class MockAuthService implements AuthService {
  MockAuthService(this._storage);

  final LocalStorageService _storage;
  final _uuid = const Uuid();
  final _userController = StreamController<UserModel?>.broadcast();

  @override
  Stream<UserModel?> get userChanges => _userController.stream;

  @override
  Future<UserModel?> getCurrentUser() {
    return _storage.getCurrentUser();
  }

  @override
  Future<UserModel?> refreshCurrentUser() => getCurrentUser();

  @override
  Future<UserModel> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final existing = await _storage.getUserByEmail(email);
    if (existing != null) {
      throw AuthException('Ya existe una cuenta con este correo.');
    }

    final userId = _uuid.v4();
    final user = UserModel(
      id: userId,
      email: email.trim().toLowerCase(),
      displayName: displayName.trim(),
      qrCode: 'RD-${_uuid.v4()}',
      createdAt: DateTime.now(),
      isActive: true,
      role: UserRole.user,
      password: password,
    );

    await _storage.saveUser(user);
    await _storage.setCurrentUserId(user.id);
    _userController.add(user);
    return user;
  }

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final user = await _storage.getUserByEmail(email);
    if (user == null) {
      throw AuthException('No existe una cuenta con este correo.');
    }
    if (user.password != password) {
      throw AuthException('Contraseña incorrecta.');
    }

    await _storage.setCurrentUserId(user.id);
    _userController.add(user);
    return user;
  }

  @override
  Future<void> logout() async {
    await _storage.clearSession();
    _userController.add(null);
  }

  void dispose() {
    _userController.close();
  }
}
