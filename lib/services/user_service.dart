import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firebase_paths.dart';
import '../models/membership_modality.dart';
import '../models/membership_status.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import '../utils/membership_helpers.dart';

abstract class UserServiceBase {
  Stream<List<UserModel>> watchAllUsers();
  Future<UserModel?> getUserById(String id);
  Future<void> setUserActive(String id, bool isActive);
  Future<void> setUserRole(String id, UserRole role);
  Future<void> setBusinessAssignment(String id, String? businessId);
  Future<void> updateMembershipProfile({
    required String id,
    required MembershipModality modality,
    required MembershipStatus status,
    DateTime? expiresAt,
    DateTime? activatedAt,
    String? whatsapp,
    String? nationalIdLast4,
    DateTime? birthDate,
    String? internalNotes,
  });
  Future<void> approveMembership(String id);
  Future<void> rejectMembership(String id);
}

class UserService implements UserServiceBase {
  UserService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      FirebasePaths.collection(_firestore, 'users');

  @override
  Stream<List<UserModel>> watchAllUsers() {
    return _users.snapshots().map((snapshot) {
      final users = snapshot.docs
          .map(UserModel.fromFirestore)
          .toList(growable: false);
      return sortUsersForAdmin(users);
    });
  }

  @override
  Future<UserModel?> getUserById(String id) async {
    final snapshot = await _users.doc(id).get();

    if (!snapshot.exists) {
      return null;
    }

    return UserModel.fromFirestore(snapshot);
  }

  @override
  Future<void> setUserActive(String id, bool isActive) async {
    await _users.doc(id).update({
      'isActive': isActive,
      'membershipStatus':
          isActive ? MembershipStatus.active.firestoreValue : MembershipStatus.inactive.firestoreValue,
    });
  }

  @override
  Future<void> setUserRole(String id, UserRole role) async {
    await _users.doc(id).update({
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

    await _users.doc(id).update(updates);
  }

  @override
  Future<void> updateMembershipProfile({
    required String id,
    required MembershipModality modality,
    required MembershipStatus status,
    DateTime? expiresAt,
    DateTime? activatedAt,
    String? whatsapp,
    String? nationalIdLast4,
    DateTime? birthDate,
    String? internalNotes,
  }) async {
    await _users.doc(id).update({
      'membershipModality': modality.firestoreValue,
      'membershipStatus': status.firestoreValue,
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt),
      if (activatedAt != null) 'activatedAt': Timestamp.fromDate(activatedAt),
      'whatsapp': ?whatsapp,
      'nationalIdLast4': ?nationalIdLast4,
      if (birthDate != null) 'birthDate': Timestamp.fromDate(birthDate),
      'internalNotes': ?internalNotes,
    });
  }

  @override
  Future<void> approveMembership(String id) async {
    final now = DateTime.now();
    await _users.doc(id).update({
      'role': UserRole.member.firestoreValue,
      'membershipStatus': MembershipStatus.active.firestoreValue,
      'isActive': true,
      'activatedAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(MembershipHelpers.defaultOfficialExpiry(now)),
    });
  }

  @override
  Future<void> rejectMembership(String id) async {
    await _users.doc(id).update({
      'membershipStatus': MembershipStatus.inactive.firestoreValue,
      'isActive': false,
    });
  }

  static List<UserModel> sortUsersForAdmin(List<UserModel> users) {
    final sorted = List<UserModel>.from(users);
    sorted.sort((a, b) {
      if (a.membershipStatus == MembershipStatus.pending &&
          b.membershipStatus != MembershipStatus.pending) {
        return -1;
      }
      if (b.membershipStatus == MembershipStatus.pending &&
          a.membershipStatus != MembershipStatus.pending) {
        return 1;
      }
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
              user.email.toLowerCase().contains(normalizedQuery) ||
              (user.whatsapp?.contains(normalizedQuery) ?? false),
        )
        .toList(growable: false);
  }
}
