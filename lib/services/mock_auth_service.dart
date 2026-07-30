import 'dart:async';

import 'package:uuid/uuid.dart';

import '../models/membership_modality.dart';
import '../models/membership_status.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import '../utils/username_helpers.dart';
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
  Future<UserModel?> resolveStartupSession() => getCurrentUser();

  @override
  Future<UserModel?> refreshCurrentUser() => getCurrentUser();

  @override
  Future<UserModel> register({
    required String email,
    required String password,
    required RegisterProfileData profile,
  }) async {
    final existing = await _storage.getUserByEmail(email);
    if (existing != null) {
      throw AuthException('Ya existe una cuenta con este correo.');
    }

    final userId = _uuid.v4();
    final user = UserModel(
      id: userId,
      email: email.trim().toLowerCase(),
      displayName: profile.displayName.trim(),
      username: profile.username.trim().isEmpty
          ? UsernameHelpers.suggestFromEmail(email)
          : UsernameHelpers.normalize(profile.username),
      usernameUpdatedAt: null,
      qrCode: 'RD-${_uuid.v4()}',
      createdAt: DateTime.now(),
      isActive: true,
      role: UserRole.user,
      password: password,
      whatsapp: profile.whatsapp,
      nationalIdLast4: profile.nationalIdLast4,
      birthDate: profile.birthDate,
      membershipModality: MembershipModality.community,
      membershipStatus: MembershipStatus.active,
      acceptedTermsAt: profile.acceptedTerms ? DateTime.now() : null,
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

  /// El almacenamiento local no manda correos: se acepta la petición para que
  /// el flujo se pueda recorrer en desarrollo.
  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> reauthenticate(String password) async {
    final user = await _storage.getCurrentUser();
    if (user == null) {
      throw AuthException('No hay sesión activa.');
    }
    if (user.password != password) {
      throw AuthException('La contraseña no es correcta.');
    }
  }

  @override
  Future<void> deleteAccount() async {
    final user = await _storage.getCurrentUser();
    if (user == null) {
      throw AuthException('No hay sesión activa.');
    }

    await _storage.deleteUser(user.id);
    await _storage.clearSession();
    _userController.add(null);
  }

  void dispose() {
    _userController.close();
  }
}
