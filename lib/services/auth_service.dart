import '../models/user_model.dart';

/// Abstract auth contract. Replace [MockAuthService] with [FirebaseAuthService]
/// when connecting Firebase Authentication + Firestore `users` collection.
abstract class AuthService {
  Stream<UserModel?> get userChanges;

  Future<UserModel?> getCurrentUser();
  Future<UserModel> register({
    required String email,
    required String password,
    required String displayName,
  });
  Future<UserModel> login({
    required String email,
    required String password,
  });
  Future<void> logout();
  Future<UserModel?> refreshCurrentUser();
}

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
