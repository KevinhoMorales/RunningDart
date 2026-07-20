import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import '../models/visit_model.dart';
import '../services/qr_service.dart';

class ScanException implements Exception {
  ScanException(this.message);

  final String message;

  @override
  String toString() => message;
}

class VisitScanValidator {
  const VisitScanValidator._();

  static void validateOperatorScan({
    required String scannedMemberId,
    required String scannedByUserId,
    required String businessId,
    required UserModel member,
  }) {
    if (scannedMemberId == scannedByUserId) {
      throw ScanException('No puedes escanear tu propio código en tu negocio.');
    }

    final memberBusinessId = member.businessId;
    if (memberBusinessId != null &&
        memberBusinessId.isNotEmpty &&
        memberBusinessId == businessId) {
      throw ScanException(
        'No puedes registrar visitas de otro operador de este negocio.',
      );
    }
  }
}

abstract class VisitServiceBase {
  Stream<List<VisitModel>> watchVisitsForBusiness(String businessId);
  Future<VisitModel> processScan({
    required String rawQrValue,
    required String businessId,
    required String scannedByUserId,
  });
}

class VisitService implements VisitServiceBase {
  VisitService({
    FirebaseFirestore? firestore,
    QRService? qrService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _qrService = qrService ?? QRService();

  final FirebaseFirestore _firestore;
  final QRService _qrService;

  static const _visitsCollection = 'visits';
  static const _usersCollection = 'users';

  @override
  Stream<List<VisitModel>> watchVisitsForBusiness(String businessId) {
    return _firestore
        .collection(_visitsCollection)
        .where('businessId', isEqualTo: businessId)
        .orderBy('visitedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map(VisitModel.fromFirestore).toList(growable: false);
    });
  }

  @override
  Future<VisitModel> processScan({
    required String rawQrValue,
    required String businessId,
    required String scannedByUserId,
  }) async {
    final payload = _qrService.parsePayload(rawQrValue);

    final userSnapshot =
        await _firestore.collection(_usersCollection).doc(payload.userId).get();

    if (!userSnapshot.exists) {
      throw ScanException('No se encontró el usuario del QR.');
    }

    final member = UserModel.fromFirestore(userSnapshot);

    VisitScanValidator.validateOperatorScan(
      scannedMemberId: payload.userId,
      scannedByUserId: scannedByUserId,
      businessId: businessId,
      member: member,
    );

    if (!member.isActive) {
      throw ScanException('La cuenta de este miembro está inactiva.');
    }

    if (!member.hasMembershipPrivileges) {
      throw ScanException('Este usuario no tiene membresía activa.');
    }

    if (member.qrCode != payload.qrCode) {
      throw ScanException('El código QR no coincide con el miembro.');
    }

    final visitRef = _firestore.collection(_visitsCollection).doc();
    final visit = VisitModel(
      id: visitRef.id,
      userId: member.id,
      businessId: businessId,
      visitedAt: DateTime.now(),
      memberDisplayName: member.displayName,
      memberQrCode: member.qrCode,
      scannedByUserId: scannedByUserId,
    );

    await visitRef.set(visit.toFirestore());
    return visit;
  }
}
