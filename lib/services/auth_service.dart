import '../models/user_model.dart';

class RegisterProfileData {
  const RegisterProfileData({
    required this.displayName,
    required this.username,
    required this.whatsapp,
    required this.nationalIdLast4,
    required this.birthDate,
    required this.acceptedTerms,
  });

  final String displayName;
  final String username;
  final String whatsapp;
  final String nationalIdLast4;
  final DateTime birthDate;
  final bool acceptedTerms;
}

/// Abstract auth contract. Replace [MockAuthService] with [FirebaseAuthService]
/// when connecting Firebase Authentication + Firestore `users` collection.
abstract class AuthService {
  Stream<UserModel?> get userChanges;

  Future<UserModel?> getCurrentUser();
  Future<UserModel?> resolveStartupSession();
  Future<UserModel> register({
    required String email,
    required String password,
    required RegisterProfileData profile,
  });
  Future<UserModel> login({
    required String email,
    required String password,
  });
  Future<void> logout();

  /// Envía el enlace para crear una contraseña nueva. No distingue entre un
  /// correo registrado y uno que no existe: eso permitiría averiguar quién
  /// tiene cuenta.
  Future<void> sendPasswordReset(String email);

  /// Vuelve a validar la contraseña de la sesión activa. Se usa como respaldo de
  /// la biometría antes de acciones irreversibles como eliminar la cuenta.
  Future<void> reauthenticate(String password);

  Future<void> deleteAccount();
  Future<UserModel?> refreshCurrentUser();
}

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
