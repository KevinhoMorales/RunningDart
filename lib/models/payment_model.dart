import 'package:cloud_firestore/cloud_firestore.dart';

import 'membership_modality.dart';

enum PaymentStatus {
  pending,
  approved,
  rejected;

  String get firestoreValue => name;

  String get displayName => switch (this) {
        PaymentStatus.pending => 'Pendiente',
        PaymentStatus.approved => 'Aprobado',
        PaymentStatus.rejected => 'Rechazado',
      };

  /// Ante un valor desconocido se asume `pending`: mostrar un pago dudoso como
  /// cobrado es peor que pedir que un admin lo revise.
  static PaymentStatus fromFirestore(String? value) {
    return switch (value) {
      'approved' => PaymentStatus.approved,
      'rejected' => PaymentStatus.rejected,
      _ => PaymentStatus.pending,
    };
  }
}

class PaymentModel {
  const PaymentModel({
    required this.id,
    required this.userId,
    required this.modality,
    required this.amount,
    required this.paidAt,
    required this.status,
    this.receiptUrl,
    this.notes,
    this.createdAt,
  });

  final String id;
  final String userId;
  final MembershipModality modality;
  final double amount;
  final DateTime paidAt;
  final PaymentStatus status;
  final String? receiptUrl;
  final String? notes;
  final DateTime? createdAt;

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'modality': modality.firestoreValue,
      'amount': amount,
      'paidAt': Timestamp.fromDate(paidAt),
      'status': status.firestoreValue,
      if (receiptUrl != null) 'receiptUrl': receiptUrl,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    };
  }

  factory PaymentModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;

    DateTime readDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      return DateTime.parse(value as String);
    }

    return PaymentModel(
      id: doc.id,
      userId: data['userId'] as String,
      modality: MembershipModality.fromFirestore(data['modality'] as String?),
      amount: (data['amount'] as num).toDouble(),
      paidAt: readDate(data['paidAt']),
      status: PaymentStatus.fromFirestore(data['status'] as String?),
      receiptUrl: data['receiptUrl'] as String?,
      notes: data['notes'] as String?,
      createdAt: data['createdAt'] != null ? readDate(data['createdAt']) : null,
    );
  }
}
