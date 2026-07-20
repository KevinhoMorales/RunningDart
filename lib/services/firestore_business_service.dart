import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/business_model.dart';
import 'business_service.dart';

class FirestoreBusinessService implements BusinessService {
  FirestoreBusinessService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  static const _collection = 'businesses';

  CollectionReference<Map<String, dynamic>> get _businesses =>
      _firestore.collection(_collection);

  @override
  Stream<List<BusinessModel>> watchAllBusinesses() {
    return _businesses.orderBy('name').snapshots().map((snapshot) {
      return snapshot.docs.map(BusinessModel.fromFirestore).toList(growable: false);
    });
  }

  @override
  Future<List<BusinessModel>> getBusinesses({String? category}) async {
    final snapshot = await _businesses.orderBy('name').get();
    final businesses =
        snapshot.docs.map(BusinessModel.fromFirestore).toList(growable: false);

    if (category == null || category == 'Todos') {
      return businesses;
    }

    return businesses
        .where((business) => business.category == category)
        .toList(growable: false);
  }

  @override
  Future<BusinessModel?> getBusinessById(String id) async {
    final snapshot = await _businesses.doc(id).get();
    if (!snapshot.exists) {
      return null;
    }
    return BusinessModel.fromFirestore(snapshot);
  }

  @override
  Future<String> createBusiness(BusinessModel business) async {
    final docRef = business.id.isEmpty
        ? _businesses.doc()
        : _businesses.doc(business.id);

    final payload = business.copyWith(id: docRef.id).toFirestore();
    await docRef.set(payload);
    return docRef.id;
  }

  @override
  Future<void> updateBusiness(BusinessModel business) async {
    await _businesses.doc(business.id).update(business.toFirestore());
  }

  @override
  Future<void> deleteBusiness(String id) async {
    await _businesses.doc(id).delete();

    try {
      await _storage.ref().child('businesses/$id/cover.jpg').delete();
    } catch (_) {
      // Cover may not exist.
    }
  }
}
