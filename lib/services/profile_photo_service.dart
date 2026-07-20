import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

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

  static const _usersCollection = 'users';

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

    try {
      final file = File(pickedFile.path);
      final storageRef = _storage.ref().child('users/$userId/profile.jpg');

      await storageRef.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final downloadUrl = await storageRef.getDownloadURL();

      await _firestore.collection(_usersCollection).doc(userId).update({
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
    return switch (exception.code) {
      'unauthorized' || 'permission-denied' =>
        'No tienes permisos para subir esta foto.',
      'object-not-found' => 'No se encontró la imagen seleccionada.',
      _ => 'No se pudo subir la foto. Intenta de nuevo.',
    };
  }
}
