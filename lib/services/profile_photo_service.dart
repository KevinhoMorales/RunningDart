import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../config/firebase_paths.dart';
import '../utils/user_messages.dart';

class ProfilePhotoException implements Exception {
  ProfilePhotoException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProfilePhotoService {
  ProfilePhotoService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    ImagePicker? picker,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _picker = picker ?? ImagePicker();

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final ImagePicker _picker;

  CollectionReference<Map<String, dynamic>> get _users =>
      FirebasePaths.collection(_firestore, 'users');

  Future<String?> pickAndUploadProfilePhoto(String userId) async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (pickedFile == null) {
      return null;
    }

    return uploadProfilePhoto(userId, pickedFile);
  }

  Future<String?> uploadProfilePhoto(
    String userId,
    XFile pickedFile,
  ) async {
    try {
      final file = File(pickedFile.path);
      final storageRef =
          FirebasePaths.storageRef(_storage, 'users/$userId/profile.jpg');

      await storageRef.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final downloadUrl = await storageRef.getDownloadURL();

      await _users.doc(userId).update({
        'photoUrl': downloadUrl,
      });

      return downloadUrl;
    } on FirebaseException catch (e) {
      throw ProfilePhotoException(_mapFirebaseError(e));
    } catch (e) {
      if (e is ProfilePhotoException) {
        rethrow;
      }
      throw ProfilePhotoException(
        'No se pudo subir la foto. Intenta de nuevo.',
      );
    }
  }

  String _mapFirebaseError(FirebaseException exception) {
    return UserMessages.storage(exception);
  }
}
