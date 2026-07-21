import '../models/user_model.dart';
import '../models/membership_modality.dart';

class RegisterProfileData {
  const RegisterProfileData({
    required this.displayName,
    required this.whatsapp,
    required this.nationalIdLast4,
    required this.birthDate,
    required this.modality,
    required this.acceptedTerms,
  });

  final String displayName;
  final String whatsapp;
  final String nationalIdLast4;
  final DateTime birthDate;
  final MembershipModality modality;
  final bool acceptedTerms;
}

/// Abstract auth contract. Replace [MockAuthService] with [FirebaseAuthService]
/// when connecting Firebase Authentication + Firestore `users` collection.
abstract class AuthService {
  Stream<UserModel?> get userChanges;

  Future<UserModel?> getCurrentUser();
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
  Future<void> deleteAccount();
  Future<UserModel?> refreshCurrentUser();
}

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
