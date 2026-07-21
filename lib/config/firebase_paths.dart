import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'app_environment.dart';

/// Resolves Firestore and Storage paths scoped by [AppEnvironment].
///
/// Firestore: `environments/{env}/{collection}/{documentId}`
/// Storage: `environments/{env}/{relativePath}`
class FirebasePaths {
  FirebasePaths._();

  static String get environment => AppEnvironment.current.name;

  static CollectionReference<Map<String, dynamic>> collection(
    FirebaseFirestore firestore,
    String name,
  ) {
    return firestore
        .collection('environments')
        .doc(environment)
        .collection(name);
  }

  static CollectionReference<Map<String, dynamic>> collectionForEnvironment(
    FirebaseFirestore firestore,
    AppEnvironment env,
    String name,
  ) {
    return firestore.collection('environments').doc(env.name).collection(name);
  }

  static DocumentReference<Map<String, dynamic>> document(
    FirebaseFirestore firestore,
    String collectionName,
    String documentId,
  ) {
    return collection(firestore, collectionName).doc(documentId);
  }

  static DocumentReference<Map<String, dynamic>> clubSettingsDocument(
    FirebaseFirestore firestore,
    String documentId,
  ) {
    return document(firestore, 'club_settings', documentId);
  }

  static String firestoreUserDocumentPath(String userId) {
    return 'environments/$environment/users/$userId';
  }

  static String storagePath(String relativePath) {
    final normalized = relativePath.startsWith('/')
        ? relativePath.substring(1)
        : relativePath;
    return 'environments/$environment/$normalized';
  }

  static Reference storageRef(
    FirebaseStorage storage,
    String relativePath,
  ) {
    return storage.ref().child(storagePath(relativePath));
  }
}
