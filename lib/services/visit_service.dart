import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firebase_paths.dart';
import '../models/business_model.dart';
import '../models/membership_status.dart';
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
      throw ScanException('No puedes escanear tu propio código en tu marca aliada.');
    }

    final memberBusinessId = member.businessId;
    if (memberBusinessId != null &&
        memberBusinessId.isNotEmpty &&
        memberBusinessId == businessId) {
      throw ScanException(
        'No puedes registrar validaciones de otro operador de esta marca.',
      );
    }
  }
}

abstract class VisitServiceBase {
  Stream<List<VisitModel>> watchVisitsForBusiness(String businessId);
  Future<ScanValidationResult> processScan({
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

  CollectionReference<Map<String, dynamic>> get _visits =>
      FirebasePaths.collection(_firestore, 'visits');

  CollectionReference<Map<String, dynamic>> get _users =>
      FirebasePaths.collection(_firestore, 'users');

  CollectionReference<Map<String, dynamic>> get _businesses =>
      FirebasePaths.collection(_firestore, 'businesses');

  @override
  Stream<List<VisitModel>> watchVisitsForBusiness(String businessId) {
    return _visits
        .where('businessId', isEqualTo: businessId)
        .snapshots()
        .map(_mapVisitSnapshot);
  }

  Stream<List<VisitModel>> watchAllVisits() {
    return _visits
        .snapshots()
        .map(_mapVisitSnapshot);
  }

  List<VisitModel> _mapVisitSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final items = snapshot.docs.map(VisitModel.fromFirestore).toList();
    items.sort((a, b) => b.visitedAt.compareTo(a.visitedAt));
    return items;
  }

  @override
  Future<ScanValidationResult> processScan({
    required String rawQrValue,
    required String businessId,
    required String scannedByUserId,
  }) async {
    final payload = _qrService.parsePayload(rawQrValue);

    final userSnapshot = await _users.doc(payload.userId).get();

    if (!userSnapshot.exists) {
      return ScanValidationResult(
        isApproved: false,
        message: 'No se encontró el miembro del QR.',
      );
    }

    final member = UserModel.fromFirestore(userSnapshot);

    try {
      VisitScanValidator.validateOperatorScan(
        scannedMemberId: payload.userId,
        scannedByUserId: scannedByUserId,
        businessId: businessId,
        member: member,
      );
    } on ScanException catch (e) {
      return ScanValidationResult(
        isApproved: false,
        message: e.message,
        memberDisplayName: member.displayName,
        memberModality: member.membershipModality,
        memberStatus: member.membershipStatus,
        expiresAt: member.expiresAt,
      );
    }

    if (member.qrCode != payload.qrCode) {
      return ScanValidationResult(
        isApproved: false,
        message: 'El código QR no coincide con el miembro.',
        memberDisplayName: member.displayName,
        memberModality: member.membershipModality,
        memberStatus: member.membershipStatus,
        expiresAt: member.expiresAt,
      );
    }

    final businessSnapshot = await _businesses.doc(businessId).get();
    final business = businessSnapshot.exists
        ? BusinessModel.fromFirestore(businessSnapshot)
        : null;

    final rejection = _evaluateMemberAccess(
      member: member,
      business: business,
    );

    if (rejection != null) {
      final visit = await _recordValidation(
        member: member,
        businessId: businessId,
        scannedByUserId: scannedByUserId,
        validationResult: ValidationResult.rejected,
        benefitUsed: business?.discount,
      );

      return ScanValidationResult(
        isApproved: false,
        message: rejection,
        visit: visit,
        memberDisplayName: member.displayName,
        memberModality: member.membershipModality,
        memberStatus: member.membershipStatus,
        expiresAt: member.expiresAt,
        benefitUsed: business?.discount,
      );
    }

    final visit = await _recordValidation(
      member: member,
      businessId: businessId,
      scannedByUserId: scannedByUserId,
      validationResult: ValidationResult.approved,
      benefitUsed: business?.discount,
    );

    return ScanValidationResult(
      isApproved: true,
      message: 'Validación registrada correctamente.',
      visit: visit,
      memberDisplayName: member.displayName,
      memberModality: member.membershipModality,
      memberStatus: member.membershipStatus,
      expiresAt: member.expiresAt,
      benefitUsed: business?.discount,
    );
  }

  String? _evaluateMemberAccess({
    required UserModel member,
    required BusinessModel? business,
  }) {
    if (!member.isActive) {
      return 'La cuenta de este miembro está inactiva.';
    }

    if (member.membershipStatus == MembershipStatus.pending) {
      return 'La membresía está pendiente de aprobación.';
    }

    if (member.membershipStatus == MembershipStatus.inactive) {
      return 'La membresía de este miembro está inactiva.';
    }

    if (member.isMembershipExpired) {
      return 'La membresía de este miembro está vencida.';
    }

    if (!member.hasMembershipPrivileges) {
      return 'Este usuario no tiene membresía activa.';
    }

    if (business != null && !business.isAllianceActive) {
      return 'Esta alianza no está activa.';
    }

    if (business != null &&
        business.validUntil != null &&
        DateTime.now().isAfter(business.validUntil!)) {
      return 'El beneficio de esta marca ya no está vigente.';
    }

    if (business != null &&
        !business.appliesToModality(member.membershipModality)) {
      return 'Este beneficio no aplica a la modalidad del miembro.';
    }

    return null;
  }

  Future<VisitModel> _recordValidation({
    required UserModel member,
    required String businessId,
    required String scannedByUserId,
    required ValidationResult validationResult,
    String? benefitUsed,
  }) async {
    final visitRef = _visits.doc();
    final visit = VisitModel(
      id: visitRef.id,
      userId: member.id,
      businessId: businessId,
      visitedAt: DateTime.now(),
      memberDisplayName: member.displayName,
      memberQrCode: member.qrCode,
      scannedByUserId: scannedByUserId,
      memberModality: member.membershipModality,
      memberStatus: member.membershipStatus,
      validationResult: validationResult,
      benefitUsed: benefitUsed,
      expiresAt: member.expiresAt,
    );

    await visitRef.set(visit.toFirestore());
    return visit;
  }
}
