import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../config/app_environment.dart';
import '../config/firebase_paths.dart';
import '../utils/user_messages.dart';
import 'auth_service.dart';

/// Cuánto contenido tiene el usuario, para poder decírselo con números antes de
/// que confirme la eliminación.
class AccountDataFootprint {
  const AccountDataFootprint({
    required this.posts,
    required this.followers,
    required this.following,
    required this.payments,
    required this.likes,
  });

  static const empty = AccountDataFootprint(
    posts: 0,
    followers: 0,
    following: 0,
    payments: 0,
    likes: 0,
  );

  final int posts;
  final int followers;
  final int following;
  final int payments;
  final int likes;
}

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

  /// Las visitas no se pueden contar aquí: las reglas solo permiten leerlas a
  /// administradores y operadores de marca.
  Future<AccountDataFootprint> summarizeMyData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw AuthException('Debes iniciar sesión para eliminar tu cuenta.');
    }

    final follows = FirebasePaths.collection(_firestore, 'follows');
    final counts = await Future.wait([
      _count(
        FirebasePaths.collection(_firestore, 'posts')
            .where('authorId', isEqualTo: uid),
      ),
      _count(follows.where('followedId', isEqualTo: uid)),
      _count(follows.where('followerId', isEqualTo: uid)),
      _count(
        FirebasePaths.collection(_firestore, 'payments')
            .where('userId', isEqualTo: uid),
      ),
      _count(
        FirebasePaths.collection(_firestore, 'post_likes')
            .where('userId', isEqualTo: uid),
      ),
    ]);

    return AccountDataFootprint(
      posts: counts[0],
      followers: counts[1],
      following: counts[2],
      payments: counts[3],
      likes: counts[4],
    );
  }

  Future<int> _count(Query<Map<String, dynamic>> query) async {
    final snapshot = await query.count().get();
    return snapshot.count ?? 0;
  }

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

  /// Limpieza desde el cliente, solo para desarrollo cuando la Cloud Function no
  /// está disponible. NO es equivalente a `deleteMyAccount`: las reglas de
  /// Firestore impiden que el dueño toque los `follows` en los que otros lo
  /// siguen, los `post_reports` y las `visits`. Esa parte solo la puede hacer la
  /// función con el Admin SDK.
  Future<void> _deleteEnvironmentData(AppEnvironment environment) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw AuthException('Debes iniciar sesión para eliminar tu cuenta.');
    }

    CollectionReference<Map<String, dynamic>> collection(String name) {
      return FirebasePaths.collectionForEnvironment(
        _firestore,
        environment,
        name,
      );
    }

    final users = collection('users');
    final userSnapshot = await users.doc(uid).get();
    if (!userSnapshot.exists) {
      throw AuthException(
        'No se encontró tu perfil en ${environment.label}.',
      );
    }
    final username = userSnapshot.data()?['username'] as String?;

    await _deleteQuery(collection('posts').where('authorId', isEqualTo: uid));
    await _deleteStoragePrefix(FirebasePaths.storagePath('posts/$uid/'));

    await _deleteQuery(
      collection('follows').where('followerId', isEqualTo: uid),
    );
    await _deleteQuery(collection('blocks').where('blockerId', isEqualTo: uid));
    await _deleteQuery(
      collection('post_likes').where('userId', isEqualTo: uid),
    );

    await _deleteQuery(collection('payments').where('userId', isEqualTo: uid));
    await _deleteStoragePrefix(FirebasePaths.storagePath('payments/$uid/'));

    await collection('public_profiles').doc(uid).delete().catchError((_) {});

    if (username != null && username.trim().isNotEmpty) {
      await collection('usernames')
          .doc(username.trim().toLowerCase())
          .delete()
          .catchError((_) {});
    }

    await _deleteStoragePrefix(FirebasePaths.storagePath('users/$uid/'));

    await users.doc(uid).delete();
  }

  Future<void> _deleteQuery(Query<Map<String, dynamic>> query) async {
    final snapshot = await query.get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete().catchError((_) {});
    }
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

  /// [prefix] es la ruta completa dentro del bucket, ya con `environments/{env}/`.
  Future<void> _deleteStoragePrefix(String prefix) async {
    final root = _storage.ref().child(prefix);
    final listing = await root.listAll();
    await Future.wait(
      listing.items.map((item) => item.delete().catchError((_) {})),
    );

    for (final nested in listing.prefixes) {
      await _deleteStoragePrefix(nested.fullPath);
    }
  }

  String _mapFunctionsError(FirebaseFunctionsException exception) {
    return UserMessages.functions(exception);
  }
}
