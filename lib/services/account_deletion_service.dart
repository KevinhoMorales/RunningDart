import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../config/app_environment.dart';
import '../config/firebase_paths.dart';
import '../utils/user_messages.dart';
import 'auth_service.dart';

class AccountDeletionService {
  AccountDeletionService({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  Future<void> deleteMyAccount() async {
    try {
      final callable = _functions.httpsCallable('deleteMyAccount');
      await callable.call({'environment': AppEnvironment.current.name});
      return;
    } on FirebaseFunctionsException catch (e) {
      if (!_shouldUseClientFallback(e)) {
        throw AuthException(_mapFunctionsError(e));
      }
    } catch (_) {
      if (!AppEnvironment.isDev) {
        throw AuthException(
          'No se pudo eliminar la cuenta. Intenta de nuevo.',
        );
      }
    }

    await _deleteEnvironmentData(AppEnvironment.current);
    await _deleteAuthUser();
  }

  bool _shouldUseClientFallback(FirebaseFunctionsException exception) {
    if (!AppEnvironment.isDev) {
      return false;
    }

    return switch (exception.code) {
      'unavailable' || 'not-found' || 'deadline-exceeded' => true,
      _ => false,
    };
  }

  Future<void> _deleteEnvironmentData(AppEnvironment environment) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw AuthException('Debes iniciar sesión para eliminar tu cuenta.');
    }

    final users = FirebasePaths.collectionForEnvironment(
      _firestore,
      environment,
      'users',
    );

    final userSnapshot = await users.doc(uid).get();
    if (!userSnapshot.exists) {
      throw AuthException(
        'No se encontró tu perfil en ${environment.label}.',
      );
    }

    final payments = FirebasePaths.collectionForEnvironment(
      _firestore,
      environment,
      'payments',
    );
    final paymentsSnapshot =
        await payments.where('userId', isEqualTo: uid).get();

    for (final payment in paymentsSnapshot.docs) {
      await payment.reference.delete();
    }

    await _deleteStoragePrefix(
      FirebasePaths.storagePath('payments/$uid/'),
    );

    await FirebasePaths.storageRef(
      _storage,
      'users/$uid/profile.jpg',
    ).delete().catchError((_) {});

    await users.doc(uid).delete();
  }

  Future<void> _deleteAuthUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return;
      }
      throw AuthException(UserMessages.auth(e));
    }
  }

  Future<void> _deleteStoragePrefix(String relativePrefix) async {
    final root = _storage.ref().child(relativePrefix);
    final listing = await root.listAll();
    await Future.wait(
      listing.items.map((item) => item.delete().catchError((_) {})),
    );

    for (final nested in listing.prefixes) {
      await _deleteStoragePrefix(
        nested.fullPath.split('/').skip(1).join('/'),
      );
    }
  }

  String _mapFunctionsError(FirebaseFunctionsException exception) {
    return UserMessages.functions(exception);
  }
}
