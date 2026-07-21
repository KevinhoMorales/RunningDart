import 'package:cloud_firestore/cloud_firestore.dart';

import 'membership_modality.dart';
import 'membership_status.dart';

enum ValidationResult {
  approved,
  rejected;

  String get firestoreValue => name;

  String get displayName => switch (this) {
        ValidationResult.approved => 'Aprobada',
        ValidationResult.rejected => 'Rechazada',
      };

  static ValidationResult fromFirestore(String? value) {
    return value == 'rejected'
        ? ValidationResult.rejected
        : ValidationResult.approved;
  }
}

class VisitModel {
  const VisitModel({
    required this.id,
    required this.userId,
    required this.businessId,
    required this.visitedAt,
    required this.memberDisplayName,
    required this.memberQrCode,
    required this.scannedByUserId,
    this.memberModality,
    this.memberStatus,
    this.validationResult = ValidationResult.approved,
    this.benefitUsed,
    this.expiresAt,
  });

  final String id;
  final String userId;
  final String businessId;
  final DateTime visitedAt;
  final String memberDisplayName;
  final String memberQrCode;
  final String scannedByUserId;
  final MembershipModality? memberModality;
  final MembershipStatus? memberStatus;
  final ValidationResult validationResult;
  final String? benefitUsed;
  final DateTime? expiresAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'businessId': businessId,
      'visitedAt': visitedAt.toIso8601String(),
      'memberDisplayName': memberDisplayName,
      'memberQrCode': memberQrCode,
      'scannedByUserId': scannedByUserId,
      'memberModality': memberModality?.firestoreValue,
      'memberStatus': memberStatus?.firestoreValue,
      'validationResult': validationResult.firestoreValue,
      'benefitUsed': benefitUsed,
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'businessId': businessId,
      'visitedAt': Timestamp.fromDate(visitedAt),
      'memberDisplayName': memberDisplayName,
      'memberQrCode': memberQrCode,
      'scannedByUserId': scannedByUserId,
      if (memberModality != null)
        'memberModality': memberModality!.firestoreValue,
      if (memberStatus != null) 'memberStatus': memberStatus!.firestoreValue,
      'validationResult': validationResult.firestoreValue,
      if (benefitUsed != null && benefitUsed!.isNotEmpty)
        'benefitUsed': benefitUsed,
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
    };
  }

  factory VisitModel.fromJson(Map<String, dynamic> json) {
    return VisitModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      businessId: json['businessId'] as String,
      visitedAt: DateTime.parse(json['visitedAt'] as String),
      memberDisplayName: json['memberDisplayName'] as String,
      memberQrCode: json['memberQrCode'] as String,
      scannedByUserId: json['scannedByUserId'] as String,
      memberModality: json['memberModality'] != null
          ? MembershipModality.fromFirestore(json['memberModality'] as String?)
          : null,
      memberStatus: json['memberStatus'] != null
          ? MembershipStatus.fromFirestore(json['memberStatus'] as String?)
          : null,
      validationResult: ValidationResult.fromFirestore(
        json['validationResult'] as String?,
      ),
      benefitUsed: json['benefitUsed'] as String?,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
    );
  }

  factory VisitModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    final visitedAt = data['visitedAt'];

    DateTime? readOptionalDate(dynamic value) {
      if (value == null) {
        return null;
      }
      if (value is Timestamp) {
        return value.toDate();
      }
      return DateTime.parse(value as String);
    }

    return VisitModel(
      id: doc.id,
      userId: data['userId'] as String,
      businessId: data['businessId'] as String,
      visitedAt: visitedAt is Timestamp
          ? visitedAt.toDate()
          : DateTime.parse(visitedAt as String),
      memberDisplayName: data['memberDisplayName'] as String,
      memberQrCode: data['memberQrCode'] as String,
      scannedByUserId: data['scannedByUserId'] as String,
      memberModality: data['memberModality'] != null
          ? MembershipModality.fromFirestore(data['memberModality'] as String?)
          : null,
      memberStatus: data['memberStatus'] != null
          ? MembershipStatus.fromFirestore(data['memberStatus'] as String?)
          : null,
      validationResult: ValidationResult.fromFirestore(
        data['validationResult'] as String?,
      ),
      benefitUsed: data['benefitUsed'] as String?,
      expiresAt: readOptionalDate(data['expiresAt']),
    );
  }
}

class ScanValidationResult {
  const ScanValidationResult({
    required this.isApproved,
    required this.message,
    this.visit,
    this.memberDisplayName,
    this.memberModality,
    this.memberStatus,
    this.expiresAt,
    this.benefitUsed,
  });

  final bool isApproved;
  final String message;
  final VisitModel? visit;
  final String? memberDisplayName;
  final MembershipModality? memberModality;
  final MembershipStatus? memberStatus;
  final DateTime? expiresAt;
  final String? benefitUsed;
}
