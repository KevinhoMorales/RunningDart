import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/firebase_paths.dart';
import '../models/user_model.dart';
import '../utils/user_messages.dart';
import '../utils/username_helpers.dart';

class UsernameException implements Exception {
  UsernameException(this.message, {this.isTaken = false});

  final String message;

  /// Permite reintentar con otro candidato sin depender del texto del mensaje.
  final bool isTaken;

  @override
  String toString() => message;
}

/// Administra la unicidad de los nombres de usuario.
///
/// La unicidad se garantiza con la coleccion `usernames/{usernameLower}`:
/// las reglas permiten crear pero no actualizar, asi que dos solicitudes
/// simultaneas nunca pueden quedarse con el mismo documento.
class UsernameService {
  UsernameService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usernames =>
      FirebasePaths.collection(_firestore, 'usernames');

  CollectionReference<Map<String, dynamic>> get _users =>
      FirebasePaths.collection(_firestore, 'users');

  CollectionReference<Map<String, dynamic>> get _publicProfiles =>
      FirebasePaths.collection(_firestore, 'public_profiles');

  Future<bool> isAvailable(String username, {String? forUserId}) async {
    final normalized = UsernameHelpers.normalize(username);
    if (!UsernameHelpers.isValid(normalized)) {
      return false;
    }
    try {
      final doc = await _usernames.doc(normalized).get();
      if (!doc.exists) {
        return true;
      }
      return forUserId != null && doc.data()?['userId'] == forUserId;
    } on FirebaseException catch (e) {
      throw UsernameException(UserMessages.firestore(e));
    }
  }

  /// Reserva el username durante el registro, antes de crear `users/{uid}`.
  Future<void> reserve({
    required String username,
    required String userId,
  }) async {
    final normalized = UsernameHelpers.normalize(username);
    final formatError = UsernameHelpers.validationError(normalized);
    if (formatError != null) {
      throw UsernameException(formatError);
    }

    try {
      // Las reglas prohiben `update`, asi que este `set` falla si ya existe.
      await _usernames.doc(normalized).set({
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'already-exists' || e.code == 'permission-denied') {
        throw UsernameException(
          'Ese nombre de usuario ya está tomado.',
          isTaken: true,
        );
      }
      throw UsernameException(UserMessages.firestore(e));
    }
  }

  /// Reserva [desired] o, si ya está tomado, el primer `desired1`, `desired2`…
  /// disponible. Devuelve el username concedido.
  Future<String> reserveAvailable({
    required String desired,
    required String userId,
  }) async {
    final base = UsernameHelpers.normalize(desired);
    for (var attempt = 0; attempt <= _maxSuffixAttempts; attempt++) {
      final candidate = attempt == 0 ? base : _withSuffix(base, attempt);
      try {
        await reserve(username: candidate, userId: userId);
        return candidate;
      } on UsernameException catch (e) {
        if (!e.isTaken) {
          rethrow;
        }
      }
    }
    throw UsernameException(
      'No pudimos generar un nombre de usuario disponible. Elige uno tú.',
    );
  }

  Future<void> release(String username) async {
    final normalized = UsernameHelpers.normalize(username);
    if (normalized.isEmpty) {
      return;
    }
    try {
      await _usernames.doc(normalized).delete();
    } on FirebaseException {
      // La reserva huerfana no bloquea al usuario: se limpia manualmente.
    }
  }

  Future<void> changeUsername({
    required String userId,
    required String newUsername,
    String? currentUsername,
    required bool bypassCooldown,
    DateTime? usernameUpdatedAt,
  }) async {
    final normalized = UsernameHelpers.normalize(newUsername);
    final formatError = UsernameHelpers.validationError(normalized);
    if (formatError != null) {
      throw UsernameException(formatError);
    }

    final previous = currentUsername == null
        ? null
        : UsernameHelpers.normalize(currentUsername);
    if (previous == normalized) {
      return;
    }

    if (!bypassCooldown && previous != null && previous.isNotEmpty) {
      final remainingDays =
          UsernameHelpers.daysUntilChangeAllowed(usernameUpdatedAt);
      if (remainingDays > 0) {
        throw UsernameException(
          'Podrás cambiar tu nombre de usuario en $remainingDays '
          '${remainingDays == 1 ? 'día' : 'días'}.',
        );
      }
    }

    if (!await isAvailable(normalized, forUserId: userId)) {
      throw UsernameException('Ese nombre de usuario ya está tomado.');
    }

    try {
      final batch = _firestore.batch();
      batch.set(_usernames.doc(normalized), {
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (previous != null && previous.isNotEmpty) {
        batch.delete(_usernames.doc(previous));
      }
      batch.update(_users.doc(userId), {
        'username': normalized,
        'usernameUpdatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(
        _publicProfiles.doc(userId),
        {
          'username': normalized,
          'usernameLower': normalized,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw UsernameException(
          'No pudimos cambiar tu nombre de usuario. Verifica que esté '
          'disponible y que haya pasado el tiempo de espera.',
        );
      }
      throw UsernameException(UserMessages.firestore(e));
    }
  }

  /// Sugiere un username libre partiendo del correo, agregando sufijos.
  Future<String> suggestAvailableFromEmail(String email) async {
    final base = UsernameHelpers.suggestFromEmail(email);
    for (var attempt = 0; attempt <= _maxSuffixAttempts; attempt++) {
      final candidate = attempt == 0 ? base : _withSuffix(base, attempt);
      if (await isAvailable(candidate)) {
        return candidate;
      }
    }
    return base;
  }

  /// Asigna un username derivado del correo a quienes todavía no tienen uno.
  ///
  /// Pensado para el respaldo del panel admin sobre cuentas creadas antes de
  /// que existiera el campo. No escribe `usernameUpdatedAt`: como el nombre no
  /// lo eligió la persona, su primer cambio no debe costarle el cooldown.
  /// Devuelve el mapa `userId -> username` de los que sí se pudieron asignar.
  Future<Map<String, String>> assignMissingUsernames(
    List<UserModel> users,
  ) async {
    final assigned = <String, String>{};

    for (final user in users) {
      if (user.username != null && user.username!.trim().isNotEmpty) {
        continue;
      }

      String? reserved;
      try {
        reserved = await reserveAvailable(
          desired: UsernameHelpers.suggestFromEmail(user.email),
          userId: user.id,
        );
        await _users.doc(user.id).update({'username': reserved});
        assigned[user.id] = reserved;
      } catch (error) {
        if (reserved != null) {
          await release(reserved);
        }
        // Un usuario problemático no debe abortar el resto del respaldo.
        debugPrint('No se pudo asignar username a ${user.id}: $error');
      }
    }

    return assigned;
  }

  static const _maxSuffixAttempts = 20;

  String _withSuffix(String base, int index) {
    final suffix = index.toString();
    final maxBaseLength = UsernameHelpers.maxLength - suffix.length;
    var trimmed =
        base.length > maxBaseLength ? base.substring(0, maxBaseLength) : base;
    while (trimmed.endsWith('.') || trimmed.endsWith('_')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return '$trimmed$suffix';
  }
}
