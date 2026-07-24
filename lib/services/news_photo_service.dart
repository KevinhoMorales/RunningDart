import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../config/firebase_paths.dart';
import '../utils/user_messages.dart';

class NewsPhotoException implements Exception {
  NewsPhotoException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NewsPhotoService {
  NewsPhotoService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    ImagePicker? picker,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _picker = picker ?? ImagePicker();

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final ImagePicker _picker;

  CollectionReference<Map<String, dynamic>> get _news =>
      FirebasePaths.collection(_firestore, 'news');

  Future<String?> pickAndUploadNewsPhoto(String newsId) async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );

    if (pickedFile == null) {
      return null;
    }

    return uploadNewsPhoto(newsId, pickedFile);
  }

  Future<String?> uploadNewsPhoto(
    String newsId,
    XFile pickedFile,
  ) async {
    try {
      final file = File(pickedFile.path);
      final storageRef =
          FirebasePaths.storageRef(_storage, 'news/$newsId/cover.jpg');

      await storageRef.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final downloadUrl = await storageRef.getDownloadURL();

      await _news.doc(newsId).update({
        'imageUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return downloadUrl;
    } on FirebaseException catch (e) {
      throw NewsPhotoException(_mapFirebaseError(e));
    } catch (e) {
      if (e is NewsPhotoException) {
        rethrow;
      }
      throw NewsPhotoException(
        'No se pudo subir la foto. Intenta de nuevo.',
      );
    }
  }

  String _mapFirebaseError(FirebaseException exception) {
    return UserMessages.storage(exception);
  }
}
