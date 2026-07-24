import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firebase_paths.dart';
import '../utils/user_messages.dart';

class ProfileUpdateException implements Exception {
  ProfileUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProfileService {
  ProfileService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      FirebasePaths.collection(_firestore, 'users');

  Future<void> updateProfile({
    required String userId,
    required String displayName,
    required String whatsapp,
    required String nationalIdLast4,
    required DateTime birthDate,
    String? bio,
  }) async {
    try {
      await _users.doc(userId).update({
        'displayName': displayName,
        'whatsapp': whatsapp,
        'nationalIdLast4': nationalIdLast4,
        'birthDate': Timestamp.fromDate(birthDate),
        'bio': (bio == null || bio.trim().isEmpty) ? null : bio.trim(),
      });
    } on FirebaseException catch (e) {
      throw ProfileUpdateException(UserMessages.firestore(e));
    } catch (_) {
      throw ProfileUpdateException(
        'No se pudieron guardar los cambios. Intenta de nuevo.',
      );
    }
  }
}
