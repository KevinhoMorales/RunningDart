import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../models/membership_status.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import 'auth_service.dart';
import 'account_deletion_service.dart';

class FirebaseAuthService implements AuthService {
  FirebaseAuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    AccountDeletionService? accountDeletionService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _accountDeletionService =
            accountDeletionService ?? AccountDeletionService() {
    _authSubscription = _auth.authStateChanges().listen(_handleAuthStateChanged);
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final AccountDeletionService _accountDeletionService;
  final _uuid = const Uuid();
  final _userController = StreamController<UserModel?>.broadcast();

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSubscription;

  static const _usersCollection = 'users';

  @override
  Stream<UserModel?> get userChanges => _userController.stream;

  @override
  Future<UserModel?> getCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      return null;
    }

    return _fetchUserProfile(firebaseUser.uid);
  }

  @override
  Future<UserModel?> refreshCurrentUser() => getCurrentUser();

  @override
  Future<UserModel> register({
    required String email,
    required String password,
    required RegisterProfileData profile,
  }) async {
    User? firebaseUser;

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw AuthException('No se pudo crear la cuenta. Intenta de nuevo.');
      }

      final now = DateTime.now();
      final requiresApproval = profile.modality.requiresPayment;
      final user = UserModel(
        id: firebaseUser.uid,
        email: email.trim().toLowerCase(),
        displayName: profile.displayName.trim(),
        qrCode: 'RD-${_uuid.v4()}',
        createdAt: now,
        isActive: true,
        role: UserRole.user,
        whatsapp: profile.whatsapp.trim(),
        nationalIdLast4: profile.nationalIdLast4.trim(),
        birthDate: profile.birthDate,
        membershipModality: profile.modality,
        membershipStatus: requiresApproval
            ? MembershipStatus.pending
            : MembershipStatus.active,
        acceptedTermsAt: profile.acceptedTerms ? now : null,
      );

      try {
        await _firestore
            .collection(_usersCollection)
            .doc(firebaseUser.uid)
            .set(user.toFirestore());

        final snapshot = await _firestore
            .collection(_usersCollection)
            .doc(firebaseUser.uid)
            .get();

        if (!snapshot.exists) {
          throw AuthException(
            'No se pudo crear tu perfil. Intenta de nuevo.',
          );
        }

        return UserModel.fromFirestore(snapshot);
      } on AuthException {
        await firebaseUser.delete();
        rethrow;
      } on FirebaseException catch (e) {
        await firebaseUser.delete();
        throw AuthException(_mapFirestoreError(e));
      } catch (_) {
        await firebaseUser.delete();
        throw AuthException(
          'No se pudo crear tu perfil. Intenta de nuevo.',
        );
      }
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    } on AuthException {
      rethrow;
    }
  }

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw AuthException('No se pudo iniciar sesión. Intenta de nuevo.');
      }

      final profile = await _fetchUserProfile(firebaseUser.uid);
      if (profile == null) {
        throw AuthException(
          'Tu perfil no está disponible. Contacta al administrador.',
        );
      }

      return profile;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    } on FirebaseException catch (e) {
      throw AuthException(_mapFirestoreError(e));
    }
  }

  @override
  Future<void> logout() async {
    await _auth.signOut();
  }

  @override
  Future<void> deleteAccount() async {
    try {
      await _accountDeletionService.deleteMyAccount();
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    } catch (_) {
      throw AuthException(
        'No se pudo eliminar la cuenta. Intenta de nuevo.',
      );
    } finally {
      if (_auth.currentUser != null) {
        await _auth.signOut();
      }
    }
  }

  Future<void> _handleAuthStateChanged(User? firebaseUser) async {
    await _profileSubscription?.cancel();
    _profileSubscription = null;

    if (firebaseUser == null) {
      _userController.add(null);
      return;
    }

    _profileSubscription = _firestore
        .collection(_usersCollection)
        .doc(firebaseUser.uid)
        .snapshots()
        .listen(
      (snapshot) {
        if (!snapshot.exists) {
          _userController.add(null);
          return;
        }

        _userController.add(UserModel.fromFirestore(snapshot));
      },
      onError: (_) {
        _userController.add(null);
      },
    );
  }

  Future<UserModel?> _fetchUserProfile(String uid) async {
    final snapshot =
        await _firestore.collection(_usersCollection).doc(uid).get();

    if (!snapshot.exists) {
      return null;
    }

    return UserModel.fromFirestore(snapshot);
  }

  String _mapFirebaseAuthError(FirebaseAuthException exception) {
    return switch (exception.code) {
      'email-already-in-use' => 'Ya existe una cuenta con este correo.',
      'invalid-email' => 'Correo inválido.',
      'weak-password' => 'La contraseña debe tener al menos 6 caracteres.',
      'user-not-found' ||
      'invalid-credential' ||
      'wrong-password' =>
        'Correo o contraseña incorrectos.',
      'user-disabled' => 'Esta cuenta ha sido deshabilitada.',
      'too-many-requests' =>
        'Demasiados intentos. Espera un momento e intenta de nuevo.',
      _ => 'Ocurrió un error inesperado. Intenta de nuevo.',
    };
  }

  String _mapFirestoreError(FirebaseException exception) {
    return switch (exception.code) {
      'permission-denied' =>
        'No tienes permisos para completar esta acción.',
      _ => 'Ocurrió un error inesperado. Intenta de nuevo.',
    };
  }

  void dispose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    _userController.close();
  }
}
