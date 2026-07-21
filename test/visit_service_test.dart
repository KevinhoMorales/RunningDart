import 'package:flutter_test/flutter_test.dart';
import 'package:running_dart/models/user_model.dart';
import 'package:running_dart/models/user_role.dart';
import 'package:running_dart/services/visit_service.dart';

void main() {
  group('VisitScanValidator', () {
    final externalMember = UserModel(
      id: 'member-1',
      email: 'member@test.com',
      displayName: 'Member One',
      qrCode: 'RD-member-1',
      createdAt: DateTime(2026, 1, 1),
      role: UserRole.member,
    );

    final operatorMember = UserModel(
      id: 'operator-2',
      email: 'operator2@test.com',
      displayName: 'Operator Two',
      qrCode: 'RD-operator-2',
      createdAt: DateTime(2026, 1, 1),
      role: UserRole.member,
      businessId: 'biz-001',
    );

    test('rejects self-scan at own business', () {
      expect(
        () => VisitScanValidator.validateOperatorScan(
          scannedMemberId: 'operator-1',
          scannedByUserId: 'operator-1',
          businessId: 'biz-001',
          member: externalMember.copyWith(id: 'operator-1'),
        ),
        throwsA(
          isA<ScanException>().having(
            (e) => e.message,
            'message',
            'No puedes escanear tu propio código en tu marca aliada.',
          ),
        ),
      );
    });

    test('rejects scan of colleague with same businessId', () {
      expect(
        () => VisitScanValidator.validateOperatorScan(
          scannedMemberId: 'operator-2',
          scannedByUserId: 'operator-1',
          businessId: 'biz-001',
          member: operatorMember,
        ),
        throwsA(
          isA<ScanException>().having(
            (e) => e.message,
            'message',
            'No puedes registrar validaciones de otro operador de esta marca.',
          ),
        ),
      );
    });

    test('allows scan of external member without businessId', () {
      expect(
        () => VisitScanValidator.validateOperatorScan(
          scannedMemberId: 'member-1',
          scannedByUserId: 'operator-1',
          businessId: 'biz-001',
          member: externalMember,
        ),
        returnsNormally,
      );
    });

    test('allows scan of member assigned to a different business', () {
      expect(
        () => VisitScanValidator.validateOperatorScan(
          scannedMemberId: 'operator-3',
          scannedByUserId: 'operator-1',
          businessId: 'biz-001',
          member: operatorMember.copyWith(
            id: 'operator-3',
            businessId: 'biz-002',
          ),
        ),
        returnsNormally,
      );
    });
  });
}
