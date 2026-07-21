import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/payment_model.dart';

class PaymentService {
  PaymentService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  static const _collection = 'payments';

  Stream<List<PaymentModel>> watchPaymentsForUser(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs.map(PaymentModel.fromFirestore).toList();
      items.sort((a, b) => b.paidAt.compareTo(a.paidAt));
      return items;
    });
  }

  Future<String> createPayment(PaymentModel payment) async {
    final docRef = payment.id.isEmpty
        ? _firestore.collection(_collection).doc()
        : _firestore.collection(_collection).doc(payment.id);
    await docRef.set(payment.toFirestore());
    return docRef.id;
  }

  Future<void> updatePaymentStatus({
    required String paymentId,
    required PaymentStatus status,
    String? notes,
  }) async {
    await _firestore.collection(_collection).doc(paymentId).update({
      'status': status.firestoreValue,
      if (notes != null) 'notes': notes,
    });
  }

  Future<String> uploadReceiptBytes({
    required String userId,
    required String paymentId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final ref = _storage.ref().child('payments/$userId/$paymentId/receipt.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }
}
