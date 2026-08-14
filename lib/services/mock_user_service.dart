import '../models/membership_modality.dart';
import '../models/membership_status.dart';
import '../models/page_result.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import 'user_service.dart';

class MockUserService implements UserServiceBase {
  @override
  Stream<PageResult<UserModel>> watchUsers({
    int limit = UserServiceBase.usersPageSize,
  }) {
    return Stream.value(const PageResult(items: [], hasMore: false));
  }

  @override
  Future<PageResult<UserModel>> fetchUsersPage({
    Object? startAfter,
    int limit = UserServiceBase.usersPageSize,
  }) async {
    return const PageResult(items: [], hasMore: false);
  }

  @override
  Future<UserModel?> getUserById(String id) async {
    return null;
  }

  @override
  Future<void> setUserActive(String id, bool isActive) async {}

  @override
  Future<void> setUserRole(String id, UserRole role) async {}

  @override
  Future<void> setBusinessAssignment(String id, String? businessId) async {}

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
  }) async {}

  @override
  Future<void> approveMembership(String id) async {}

  @override
  Future<void> rejectMembership(String id) async {}
}
