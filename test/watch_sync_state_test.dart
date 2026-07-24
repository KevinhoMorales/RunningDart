import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_dart/models/membership_modality.dart';
import 'package:running_dart/models/membership_status.dart';
import 'package:running_dart/models/user_model.dart';
import 'package:running_dart/models/user_role.dart';
import 'package:running_dart/models/watch_sync_state.dart';

UserModel _baseUser({
  required String id,
  UserRole role = UserRole.user,
  MembershipStatus membershipStatus = MembershipStatus.active,
  bool isActive = true,
  DateTime? expiresAt,
  String? businessId,
}) {
  return UserModel(
    id: id,
    email: '$id@test.com',
    displayName: 'Test User',
    qrCode: 'RD-$id',
    createdAt: DateTime(2026, 1, 1),
    role: role,
    membershipStatus: membershipStatus,
    membershipModality: MembershipModality.community,
    isActive: isActive,
    expiresAt: expiresAt,
    businessId: businessId,
  );
}

void main() {
  group('WatchSyncState.fromUser', () {
    test('without session returns logged out state', () {
      final state = WatchSyncState.fromUser(null);

      expect(state.isLoggedIn, isFalse);
      expect(state.canShowQr, isFalse);
      expect(state.qrPayload, isNull);

      final json = state.toJson();
      expect(json['isLoggedIn'], isFalse);
      expect(json.containsKey('qrPayload'), isFalse);
      expect(json.containsKey('displayName'), isFalse);
    });

    test('logged in without membership omits qr fields in json', () {
      final state = WatchSyncState.fromUser(_baseUser(id: 'user-1'));
      final json = state.toJson();

      expect(json['isLoggedIn'], isTrue);
      expect(json['canShowQr'], isFalse);
      expect(json.containsKey('qrPayload'), isFalse);
    });

    test('revoked membership clears qr access', () {
      final activeMember = _baseUser(id: 'member-1', role: UserRole.member);
      final revokedMember = _baseUser(
        id: 'member-1',
        role: UserRole.member,
        membershipStatus: MembershipStatus.inactive,
      );

      expect(WatchSyncState.fromUser(activeMember).canShowQr, isTrue);
      expect(WatchSyncState.fromUser(revokedMember).canShowQr, isFalse);
    });

    test('active user role without membership cannot show qr', () {
      final state = WatchSyncState.fromUser(_baseUser(id: 'user-1'));

      expect(state.isLoggedIn, isTrue);
      expect(state.canShowQr, isFalse);
      expect(state.qrPayload, isNull);
    });

    test('active member can show qr with payload', () {
      final user = _baseUser(id: 'member-1', role: UserRole.member);
      final state = WatchSyncState.fromUser(user);

      expect(state.canShowQr, isTrue);
      expect(state.qrPayload, isNotNull);

      final payload = jsonDecode(state.qrPayload!) as Map<String, dynamic>;
      expect(payload['userId'], user.id);
      expect(payload['qrCode'], user.qrCode);
    });

    test('active admin can show qr', () {
      final state = WatchSyncState.fromUser(
        _baseUser(
          id: 'admin-1',
          role: UserRole.admin,
          membershipStatus: MembershipStatus.pending,
          expiresAt: DateTime(2025, 1, 1),
        ),
      );

      expect(state.canShowQr, isTrue);
      expect(state.qrPayload, isNotNull);
    });

    test('pending member cannot show qr', () {
      final state = WatchSyncState.fromUser(
        _baseUser(
          id: 'pending-1',
          role: UserRole.member,
          membershipStatus: MembershipStatus.pending,
        ),
      );

      expect(state.isLoggedIn, isTrue);
      expect(state.canShowQr, isFalse);
    });

    test('expired member cannot show qr', () {
      final state = WatchSyncState.fromUser(
        _baseUser(
          id: 'expired-1',
          role: UserRole.member,
          expiresAt: DateTime(2025, 12, 31),
        ),
      );

      expect(state.canShowQr, isFalse);
    });

    test('business operator without membership privileges cannot show qr', () {
      final state = WatchSyncState.fromUser(
        _baseUser(
          id: 'operator-1',
          businessId: 'biz-1',
        ),
      );

      expect(state.isLoggedIn, isTrue);
      expect(state.canShowQr, isFalse);
    });
  });
}
