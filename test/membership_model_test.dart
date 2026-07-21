import 'package:flutter_test/flutter_test.dart';
import 'package:running_dart/models/membership_modality.dart';
import 'package:running_dart/models/membership_status.dart';
import 'package:running_dart/models/user_model.dart';
import 'package:running_dart/models/user_role.dart';
import 'package:running_dart/utils/membership_helpers.dart';

void main() {
  group('MembershipModality', () {
    test('paid modalities require payment', () {
      expect(MembershipModality.official.requiresPayment, isTrue);
      expect(MembershipModality.proTeam.requiresPayment, isTrue);
      expect(MembershipModality.community.requiresPayment, isFalse);
    });

    test('registrable options include community and paid modalities', () {
      expect(
        MembershipModality.registrableOptions,
        [
          MembershipModality.community,
          MembershipModality.official,
          MembershipModality.proTeam,
        ],
      );
    });
  });

  group('UserModel membership helpers', () {
    test('detects expired active membership', () {
      final user = UserModel(
        id: 'member-1',
        email: 'member@test.com',
        displayName: 'Member',
        qrCode: 'RD-member-1',
        createdAt: DateTime(2026, 1, 1),
        role: UserRole.member,
        membershipStatus: MembershipStatus.active,
        expiresAt: DateTime(2025, 12, 31),
      );

      expect(user.isMembershipExpired, isTrue);
    });

    test('pending membership blocks credential access', () {
      final user = UserModel(
        id: 'pending-1',
        email: 'pending@test.com',
        displayName: 'Pending',
        qrCode: 'RD-pending-1',
        createdAt: DateTime(2026, 1, 1),
        membershipStatus: MembershipStatus.pending,
        membershipModality: MembershipModality.official,
      );

      expect(user.isMembershipPending, isTrue);
      expect(user.hasMembershipPrivileges, isFalse);
    });

    test('admin keeps membership privileges without expiry', () {
      final admin = UserModel(
        id: 'admin-1',
        email: 'admin@test.com',
        displayName: 'Admin',
        qrCode: 'RD-admin-1',
        createdAt: DateTime(2026, 1, 1),
        role: UserRole.admin,
        membershipStatus: MembershipStatus.pending,
        expiresAt: DateTime(2025, 1, 1),
      );

      expect(admin.hasMembershipPrivileges, isTrue);
    });
  });

  group('MembershipHelpers', () {
    test('default official expiry ends on December 31', () {
      final expiry = MembershipHelpers.defaultOfficialExpiry(DateTime(2026, 3, 15));
      expect(expiry.year, 2026);
      expect(expiry.month, 12);
      expect(expiry.day, 31);
    });

    test('validates national id last four digits', () {
      expect(MembershipHelpers.isValidNationalIdLast4('1234'), isTrue);
      expect(MembershipHelpers.isValidNationalIdLast4('12ab'), isFalse);
    });
  });
}
