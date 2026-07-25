import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../config/firebase_paths.dart';
import '../models/payment_model.dart';

class PaymentService {
  PaymentService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _payments =>
      FirebasePaths.collection(_firestore, 'payments');

  Stream<List<PaymentModel>> watchPaymentsForUser(String userId) {
    return _payments
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
        ? _payments.doc()
        : _payments.doc(payment.id);
    await docRef.set(payment.toFirestore());
    return docRef.id;
  }

  Future<void> updatePaymentStatus({
    required String paymentId,
    required PaymentStatus status,
    String? notes,
  }) async {
    await _payments.doc(paymentId).update({
      'status': status.firestoreValue,
      'notes': ?notes,
    });
  }

  Future<String> uploadReceiptBytes({
    required String userId,
    required String paymentId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final ref = FirebasePaths.storageRef(
      _storage,
      'payments/$userId/$paymentId/receipt.jpg',
    );
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }
}
