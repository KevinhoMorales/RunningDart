import 'package:flutter_test/flutter_test.dart';
import 'package:running_dart/models/user_model.dart';
import 'package:running_dart/models/user_role.dart';
import 'package:running_dart/services/qr_service.dart';

void main() {
  group('UserRole', () {
    test('fromFirestore maps known roles', () {
      expect(UserRole.fromFirestore('user'), UserRole.user);
      expect(UserRole.fromFirestore('member'), UserRole.member);
      expect(UserRole.fromFirestore('admin'), UserRole.admin);
      expect(UserRole.fromFirestore(null), UserRole.user);
      expect(UserRole.fromFirestore('unknown'), UserRole.user);
    });

    test('fromFirestore maps legacy business role to member', () {
      expect(UserRole.fromFirestore('business'), UserRole.member);
    });

    test('membership privileges apply to member and admin only', () {
      expect(UserRole.user.hasMembershipPrivileges, isFalse);
      expect(UserRole.member.hasMembershipPrivileges, isTrue);
      expect(UserRole.admin.hasMembershipPrivileges, isTrue);
    });

    test('displayName returns Spanish labels', () {
      expect(UserRole.user.displayName, 'Usuario');
      expect(UserRole.member.displayName, 'Miembro');
      expect(UserRole.admin.displayName, 'Administrador');
    });
  });

  group('UserModel', () {
    final baseUser = UserModel(
      id: '1',
      email: 'test@example.com',
      displayName: 'Test User',
      qrCode: 'QR-123',
      createdAt: DateTime(2026, 1, 1),
      isActive: true,
    );

    test('delegates membership privileges to role', () {
      expect(
        baseUser.copyWith(role: UserRole.member).hasMembershipPrivileges,
        isTrue,
      );
      expect(
        baseUser.copyWith(role: UserRole.user).hasMembershipPrivileges,
        isFalse,
      );
    });

    test('business operator is derived from businessId', () {
      final operator = baseUser.copyWith(
        role: UserRole.member,
        businessId: 'biz-001',
      );
      expect(operator.isBusinessOperator, isTrue);
      expect(operator.canScanQr, isTrue);
      expect(operator.hasMembershipPrivileges, isTrue);
    });

    test('user without businessId is not an operator', () {
      expect(baseUser.isBusinessOperator, isFalse);
      expect(baseUser.canScanQr, isFalse);
    });
  });

  group('QRService', () {
    final service = QRService();

    test('parsePayload reads valid JSON', () {
      final payload = service.parsePayload(
        '{"userId":"uid-1","qrCode":"RD-abc"}',
      );
      expect(payload.userId, 'uid-1');
      expect(payload.qrCode, 'RD-abc');
    });

    test('parsePayload rejects invalid JSON', () {
      expect(
        () => service.parsePayload('not-json'),
        throwsA(isA<QRParseException>()),
      );
    });

    test('parsePayload rejects missing fields', () {
      expect(
        () => service.parsePayload('{"userId":"uid-1"}'),
        throwsA(isA<QRParseException>()),
      );
    });
  });
}
