import 'package:flutter_test/flutter_test.dart';
import 'package:running_dart/models/membership_modality.dart';
import 'package:running_dart/models/membership_status.dart';
import 'package:running_dart/models/user_model.dart';
import 'package:running_dart/models/user_role.dart';
import 'package:running_dart/providers/auth_provider.dart';
import 'package:running_dart/services/auth_service.dart';

class _StaticAuthService implements AuthService {
  _StaticAuthService(this._user);

  UserModel? _user;

  @override
  Stream<UserModel?> get userChanges => Stream.value(_user);

  @override
  Future<UserModel?> getCurrentUser() async => _user;

  @override
  Future<UserModel?> resolveStartupSession() async => _user;

  @override
  Future<UserModel?> refreshCurrentUser() async => _user;

  @override
  Future<UserModel> register({
    required String email,
    required String password,
    required RegisterProfileData profile,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {
    _user = null;
  }

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> reauthenticate(String password) async {}

  @override
  Future<void> deleteAccount() async {}
}

UserModel _user({
  required MembershipModality modality,
  required MembershipStatus status,
  bool isActive = true,
}) {
  return UserModel(
    id: 'user-1',
    email: 'test@example.com',
    displayName: 'Test User',
    qrCode: 'RD-abc',
    createdAt: DateTime(2026, 1, 1),
    isActive: isActive,
    role: UserRole.user,
    membershipModality: modality,
    membershipStatus: status,
  );
}

void main() {
  test('postAuthRoute sends community users to home', () async {
    final auth = AuthProvider(
      _StaticAuthService(
        _user(
          modality: MembershipModality.community,
          status: MembershipStatus.active,
        ),
      ),
    );
    await auth.initialize();

    expect(auth.postAuthRoute, '/home');
  });

  test('postAuthRoute sends pending official users to membership-pending', () async {
    final auth = AuthProvider(
      _StaticAuthService(
        _user(
          modality: MembershipModality.official,
          status: MembershipStatus.pending,
        ),
      ),
    );
    await auth.initialize();

    expect(auth.isMembershipPending, isTrue);
    expect(auth.postAuthRoute, '/membership-pending');
  });

  test('postAuthRoute sends pending pro team users to membership-pending', () async {
    final auth = AuthProvider(
      _StaticAuthService(
        _user(
          modality: MembershipModality.proTeam,
          status: MembershipStatus.pending,
        ),
      ),
    );
    await auth.initialize();

    expect(auth.postAuthRoute, '/membership-pending');
  });
}
