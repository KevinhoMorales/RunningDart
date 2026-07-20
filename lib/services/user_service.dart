import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import '../models/user_role.dart';

abstract class UserServiceBase {
  Stream<List<UserModel>> watchAllUsers();
  Future<UserModel?> getUserById(String id);
  Future<void> setUserActive(String id, bool isActive);
  Future<void> setUserRole(String id, UserRole role);
  Future<void> setBusinessAssignment(String id, String? businessId);
}

class UserService implements UserServiceBase {
  UserService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const _usersCollection = 'users';

  @override
  Stream<List<UserModel>> watchAllUsers() {
    return _firestore.collection(_usersCollection).snapshots().map((snapshot) {
      final users = snapshot.docs
          .map(UserModel.fromFirestore)
          .toList(growable: false);
      return sortUsersForAdmin(users);
    });
  }

  @override
  Future<UserModel?> getUserById(String id) async {
    final snapshot =
        await _firestore.collection(_usersCollection).doc(id).get();

    if (!snapshot.exists) {
      return null;
    }

    return UserModel.fromFirestore(snapshot);
  }

  @override
  Future<void> setUserActive(String id, bool isActive) async {
    await _firestore.collection(_usersCollection).doc(id).update({
      'isActive': isActive,
    });
  }

  @override
  Future<void> setUserRole(String id, UserRole role) async {
    await _firestore.collection(_usersCollection).doc(id).update({
      'role': role.firestoreValue,
    });
  }

  @override
  Future<void> setBusinessAssignment(String id, String? businessId) async {
    final user = await getUserById(id);
    if (user == null) {
      throw StateError('User not found: $id');
    }

    final updates = <String, dynamic>{};

    if (businessId == null || businessId.isEmpty) {
      updates['businessId'] = FieldValue.delete();
    } else {
      updates['businessId'] = businessId;
      if (user.role == UserRole.user) {
        updates['role'] = UserRole.member.firestoreValue;
      }
    }

    await _firestore.collection(_usersCollection).doc(id).update(updates);
  }

  static List<UserModel> sortUsersForAdmin(List<UserModel> users) {
    final sorted = List<UserModel>.from(users);
    sorted.sort((a, b) {
      if (a.isActive != b.isActive) {
        return a.isActive ? 1 : -1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }

  static List<UserModel> filterUsers(List<UserModel> users, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return users;
    }

    return users
        .where(
          (user) =>
              user.displayName.toLowerCase().contains(normalizedQuery) ||
              user.email.toLowerCase().contains(normalizedQuery),
        )
        .toList(growable: false);
  }
}
