import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../config/firebase_paths.dart';
import '../utils/user_messages.dart';

class BusinessPhotoException implements Exception {
  BusinessPhotoException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BusinessPhotoService {
  BusinessPhotoService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    ImagePicker? picker,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _picker = picker ?? ImagePicker();

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final ImagePicker _picker;

  CollectionReference<Map<String, dynamic>> get _businesses =>
      FirebasePaths.collection(_firestore, 'businesses');

  Future<String?> pickAndUploadBusinessPhoto(String businessId) async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );

    if (pickedFile == null) {
      return null;
    }

    return uploadBusinessPhoto(businessId, pickedFile);
  }

  Future<String?> uploadBusinessPhoto(
    String businessId,
    XFile pickedFile,
  ) async {
    try {
      final file = File(pickedFile.path);
      final storageRef = FirebasePaths.storageRef(
        _storage,
        'businesses/$businessId/cover.jpg',
      );

      await storageRef.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final downloadUrl = await storageRef.getDownloadURL();

      await _businesses.doc(businessId).update({'imageUrl': downloadUrl});

      return downloadUrl;
    } on FirebaseException catch (e) {
      throw BusinessPhotoException(_mapFirebaseError(e));
    } catch (e) {
      if (e is BusinessPhotoException) {
        rethrow;
      }
      throw BusinessPhotoException(
        'No se pudo subir la foto. Intenta de nuevo.',
      );
    }
  }

  String _mapFirebaseError(FirebaseException exception) {
    return UserMessages.storage(exception);
  }
}
