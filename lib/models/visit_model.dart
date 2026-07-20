import 'package:cloud_firestore/cloud_firestore.dart';

class VisitModel {
  const VisitModel({
    required this.id,
    required this.userId,
    required this.businessId,
    required this.visitedAt,
    required this.memberDisplayName,
    required this.memberQrCode,
    required this.scannedByUserId,
  });

  final String id;
  final String userId;
  final String businessId;
  final DateTime visitedAt;
  final String memberDisplayName;
  final String memberQrCode;
  final String scannedByUserId;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'businessId': businessId,
      'visitedAt': visitedAt.toIso8601String(),
      'memberDisplayName': memberDisplayName,
      'memberQrCode': memberQrCode,
      'scannedByUserId': scannedByUserId,
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
    );
  }

  factory VisitModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    final visitedAt = data['visitedAt'];

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
    );
  }
}
