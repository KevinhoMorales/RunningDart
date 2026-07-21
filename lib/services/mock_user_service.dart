import '../models/membership_modality.dart';
import '../models/membership_status.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import 'user_service.dart';

class MockUserService implements UserServiceBase {
  @override
  Stream<List<UserModel>> watchAllUsers() {
    return Stream.value(const []);
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
