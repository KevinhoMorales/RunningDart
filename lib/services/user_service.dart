import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firebase_paths.dart';
import '../models/membership_modality.dart';
import '../models/membership_status.dart';
import '../models/page_result.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import '../utils/membership_helpers.dart';

abstract class UserServiceBase {
  static const usersPageSize = 40;

  /// Primera página en vivo (más recientes). El panel Admin pagina con
  /// [fetchUsersPage]; el sort "pendientes primero" se aplica sobre lo cargado.
  Stream<PageResult<UserModel>> watchUsers({
    int limit = usersPageSize,
  });

  Future<PageResult<UserModel>> fetchUsersPage({
    Object? startAfter,
    int limit = usersPageSize,
  });

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
  Stream<PageResult<UserModel>> watchUsers({
    int limit = UserServiceBase.usersPageSize,
  }) {
    return _usersQuery(limit: limit).snapshots().map(
          (snapshot) => _pageFromSnapshot(snapshot, limit),
        );
  }

  @override
  Future<PageResult<UserModel>> fetchUsersPage({
    Object? startAfter,
    int limit = UserServiceBase.usersPageSize,
  }) async {
    var query = _usersQuery(limit: limit);
    if (startAfter is DocumentSnapshot<Map<String, dynamic>>) {
      query = query.startAfterDocument(startAfter);
    } else if (startAfter != null) {
      throw ArgumentError('Cursor de usuarios inválido.');
    }
    final snapshot = await query.get();
    return _pageFromSnapshot(snapshot, limit);
  }

  Query<Map<String, dynamic>> _usersQuery({required int limit}) {
    return _users.orderBy('createdAt', descending: true).limit(limit);
  }

  PageResult<UserModel> _pageFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    int limit,
  ) {
    final users = snapshot.docs
        .map(UserModel.fromFirestore)
        .toList(growable: false);
    final lastDoc = snapshot.docs.isEmpty ? null : snapshot.docs.last;
    // No reordenar aquí: el AdminProvider ordena el conjunto cargado entero
    // (pendientes primero) al fusionar páginas.
    return PageResult<UserModel>(
      items: users,
      hasMore: snapshot.docs.length >= limit,
      cursor: lastDoc,
    );
  }

  /// Conteos del resumen Admin (sin bajar la lista completa).
  Future<({int total, int pending, int activeMembers, int operators})>
      countAdminUserStats() async {
    final totalSnap = await _users.count().get();
    final pendingSnap = await _users
        .where(
          'membershipStatus',
          isEqualTo: MembershipStatus.pending.firestoreValue,
        )
        .count()
        .get();
    final activeSnap = await _users
        .where('isActive', isEqualTo: true)
        .where(
          'membershipStatus',
          isEqualTo: MembershipStatus.active.firestoreValue,
        )
        .where('role', isEqualTo: UserRole.member.firestoreValue)
        .count()
        .get();
    final operatorsSnap =
        await _users.where('businessId', isNotEqualTo: '').count().get();
    return (
      total: totalSnap.count ?? 0,
      pending: pendingSnap.count ?? 0,
      activeMembers: activeSnap.count ?? 0,
      operators: operatorsSnap.count ?? 0,
    );
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
    // Sin esto, "Guardar membresía" con estado Activo dejaba al socio en rol
    // `user` y con el QR bloqueado, aunque la ficha dijera que estaba activo.
    // Solo se promueve desde `user`: coach y admin conservan su rol.
    final user = await getUserById(id);
    final shouldPromote =
        status == MembershipStatus.active && user?.role == UserRole.user;

    await _users.doc(id).update({
      if (shouldPromote) 'role': UserRole.member.firestoreValue,
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
