import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/app_environment.dart';
import '../config/firebase_paths.dart';
import '../models/membership_status.dart';
import '../models/public_profile.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import '../utils/user_messages.dart';
import '../utils/username_helpers.dart';
import 'auth_service.dart';
import 'account_deletion_service.dart';
import 'username_service.dart';

class FirebaseAuthService implements AuthService {
  FirebaseAuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    AccountDeletionService? accountDeletionService,
    UsernameService? usernameService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _accountDeletionService =
            accountDeletionService ?? AccountDeletionService(),
        _usernameService =
            usernameService ?? UsernameService(firestore: firestore) {
    _authSubscription = _auth.authStateChanges().listen(_handleAuthStateChanged);
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final AccountDeletionService _accountDeletionService;
  final UsernameService _usernameService;
  final _uuid = const Uuid();
  final _userController = StreamController<UserModel?>.broadcast();

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSubscription;
  String? _listeningProfileUid;
  UserModel? _cachedUser;
  String? _syncedPublicProfile;
  bool _suppressProfileValidation = false;

  CollectionReference<Map<String, dynamic>> get _users =>
      FirebasePaths.collection(_firestore, 'users');

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
  Future<UserModel?> refreshCurrentUser() => resolveStartupSession();

  @override
  Future<UserModel?> resolveStartupSession() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      _logStartupProfileCheck(null, found: false);
      return null;
    }

    final documentPath =
        FirebasePaths.firestoreUserDocumentPath(firebaseUser.uid);
    final profile = await _fetchUserProfile(firebaseUser.uid);
    if (profile == null) {
      _logStartupProfileCheck(documentPath, found: false);
      await _invalidateSessionDueToMissingProfile();
      return null;
    }

    _logStartupProfileCheck(documentPath, found: true);
    await _attachProfileListener(firebaseUser.uid);
    _emitUser(profile);
    return profile;
  }

  @override
  Future<UserModel> register({
    required String email,
    required String password,
    required RegisterProfileData profile,
  }) async {
    _suppressProfileValidation = true;
    User? firebaseUser;
    var createdAuthUser = false;

    try {
      try {
        final credential = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );

        firebaseUser = credential.user;
        createdAuthUser = true;
      } on FirebaseAuthException catch (e) {
        if (e.code != 'email-already-in-use') {
          throw AuthException(_mapFirebaseAuthError(e));
        }

        final credential = await _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        firebaseUser = credential.user;
      }

      if (firebaseUser == null) {
        throw AuthException('No se pudo crear la cuenta. Intenta de nuevo.');
      }

      final existingProfile = await _fetchUserProfile(firebaseUser.uid);
      if (existingProfile != null) {
        throw AuthException(
          'Ya tienes una cuenta en ${AppEnvironment.displayName} con este correo.',
        );
      }

      final desiredUsername = profile.username.trim().isEmpty
          ? UsernameHelpers.suggestFromEmail(email)
          : UsernameHelpers.normalize(profile.username);
      final String username;
      try {
        // Si alguien tomó el nombre entre la validación y este punto, se
        // concede el siguiente libre en vez de perder el registro completo.
        username = await _usernameService.reserveAvailable(
          desired: desiredUsername,
          userId: firebaseUser.uid,
        );
      } on UsernameException catch (e) {
        if (createdAuthUser) {
          await firebaseUser.delete();
        }
        throw AuthException(e.message);
      }

      final now = DateTime.now();
      final requiresApproval = profile.modality.requiresPayment;
      final user = UserModel(
        id: firebaseUser.uid,
        email: email.trim().toLowerCase(),
        displayName: profile.displayName.trim(),
        username: username,
        // Se deja sin marcar a propósito: el cooldown de 30 días solo debe
        // empezar cuando la persona cambie el nombre por su cuenta.
        usernameUpdatedAt: null,
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
        await _users.doc(firebaseUser.uid).set(user.toFirestore());

        final snapshot = await _users.doc(firebaseUser.uid).get();

        if (!snapshot.exists) {
          throw AuthException(
            'No se pudo crear tu perfil. Intenta de nuevo.',
          );
        }

        final createdUser = UserModel.fromFirestore(snapshot);
        await _attachProfileListener(firebaseUser.uid);
        _emitUser(createdUser);
        return createdUser;
      } on AuthException {
        await _usernameService.release(username);
        if (createdAuthUser) {
          await firebaseUser.delete();
        }
        rethrow;
      } on FirebaseException catch (e) {
        await _usernameService.release(username);
        if (createdAuthUser) {
          await firebaseUser.delete();
        }
        throw AuthException(_mapFirestoreError(e));
      } catch (_) {
        await _usernameService.release(username);
        if (createdAuthUser) {
          await firebaseUser.delete();
        }
        throw AuthException(
          'No se pudo crear tu perfil. Intenta de nuevo.',
        );
      }
    } finally {
      _suppressProfileValidation = false;
    }
  }

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    _suppressProfileValidation = true;
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
        await _auth.signOut();
        throw AuthException(
          'Tu perfil no está disponible en ${AppEnvironment.displayName}. '
          'Regístrate en esta app para crear tu perfil.',
        );
      }

      _emitUser(profile);
      await _attachProfileListener(firebaseUser.uid);
      return profile;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    } on FirebaseException catch (e) {
      throw AuthException(_mapFirestoreError(e));
    } finally {
      _suppressProfileValidation = false;
    }
  }

  @override
  Future<void> logout() async {
    await _auth.signOut();
  }

  @override
  Future<void> reauthenticate(String password) async {
    final firebaseUser = _auth.currentUser;
    final email = firebaseUser?.email;
    if (firebaseUser == null || email == null || email.isEmpty) {
      throw AuthException('No hay sesión activa.');
    }

    _suppressProfileValidation = true;
    try {
      await firebaseUser.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapReauthenticationError(e));
    } catch (_) {
      throw AuthException(
        'No se pudo verificar tu contraseña. Intenta de nuevo.',
      );
    } finally {
      _suppressProfileValidation = false;
    }
  }

  String _mapReauthenticationError(FirebaseAuthException exception) {
    return switch (exception.code) {
      'wrong-password' || 'invalid-credential' || 'invalid-login-credentials' =>
        'La contraseña no es correcta.',
      'too-many-requests' =>
        'Demasiados intentos fallidos. Espera unos minutos e intenta de nuevo.',
      _ => _mapFirebaseAuthError(exception),
    };
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
    }

    if (_auth.currentUser != null) {
      await _auth.signOut();
    }
  }

  Future<void> _handleAuthStateChanged(User? firebaseUser) async {
    if (_suppressProfileValidation) {
      return;
    }

    if (firebaseUser == null) {
      // Ignora eventos null transitorios durante registro/login.
      await Future<void>.delayed(Duration.zero);
      if (_auth.currentUser != null) {
        return;
      }

      await _profileSubscription?.cancel();
      _profileSubscription = null;
      _listeningProfileUid = null;
      _cachedUser = null;
      if (!_userController.isClosed) {
        _userController.add(null);
      }
      return;
    }

    if (_listeningProfileUid == firebaseUser.uid &&
        _profileSubscription != null) {
      return;
    }

    await _syncProfileFromUid(firebaseUser.uid);
    if (_auth.currentUser?.uid != firebaseUser.uid) {
      return;
    }

    await _attachProfileListener(firebaseUser.uid);
  }

  Future<void> _attachProfileListener(String uid) async {
    if (_listeningProfileUid == uid && _profileSubscription != null) {
      return;
    }

    await _profileSubscription?.cancel();
    _profileSubscription = null;
    _listeningProfileUid = uid;

    _profileSubscription = _users.doc(uid).snapshots().listen(
      (snapshot) {
        if (_auth.currentUser?.uid != uid) {
          return;
        }

        if (snapshot.exists) {
          try {
            _emitUser(UserModel.fromFirestore(snapshot));
          } catch (error, stackTrace) {
            debugPrint(
              'Failed to parse user profile snapshot: $error\n$stackTrace',
            );
          }
          return;
        }

        unawaited(_invalidateSessionDueToMissingProfile());
      },
      onError: (error, stackTrace) {
        debugPrint('User profile listener failed: $error\n$stackTrace');
        if (_auth.currentUser?.uid == uid) {
          unawaited(_syncProfileFromUid(uid));
        }
      },
    );
  }

  Future<void> _invalidateSessionDueToMissingProfile() async {
    if (_suppressProfileValidation) {
      return;
    }

    await _profileSubscription?.cancel();
    _profileSubscription = null;
    _listeningProfileUid = null;
    _cachedUser = null;

    if (_auth.currentUser != null) {
      await _auth.signOut();
    }

    if (!_userController.isClosed) {
      _userController.add(null);
    }
  }

  void _emitUser(UserModel? user) {
    if (user != null) {
      _cachedUser = user;
      unawaited(_syncPublicProfile(user));
      if (!_userController.isClosed) {
        _userController.add(_cachedUser);
      }
      return;
    }

    if (_auth.currentUser == null) {
      _cachedUser = null;
      _syncedPublicProfile = null;
      if (!_userController.isClosed) {
        _userController.add(null);
      }
      return;
    }

    unawaited(_invalidateSessionDueToMissingProfile());
  }

  /// `public_profiles` es lo único que los demás socios pueden leer: las reglas
  /// no permiten leer el `users/{uid}` de otra persona. Si no se mantiene al
  /// día, el usuario aparece sin nombre en seguidores, búsquedas y feed.
  Future<void> _syncPublicProfile(UserModel user) async {
    final displayName = user.displayName.trim();
    if (displayName.isEmpty) {
      return;
    }

    final signature = [
      user.id,
      displayName,
      user.photoUrl ?? '',
      user.bio ?? '',
      user.username ?? '',
    ].join('|');
    if (signature == _syncedPublicProfile) {
      return;
    }
    _syncedPublicProfile = signature;

    try {
      await FirebasePaths.collection(_firestore, 'public_profiles')
          .doc(user.id)
          .set(
            PublicProfile(
              id: user.id,
              displayName: displayName,
              photoUrl: user.photoUrl,
              bio: user.bio,
              username: user.username,
            ).toFirestore(),
            SetOptions(merge: true),
          );
    } catch (error) {
      // Que falle no debe bloquear la sesión; se reintenta en la próxima
      // emisión del perfil.
      _syncedPublicProfile = null;
      debugPrint('Failed to sync public profile: $error');
    }
  }

  Future<void> _syncProfileFromUid(String uid) async {
    if (_auth.currentUser?.uid != uid) {
      return;
    }

    final profile = await _fetchUserProfile(uid);
    if (_auth.currentUser?.uid != uid) {
      return;
    }

    if (profile != null) {
      _emitUser(profile);
      return;
    }

    await _invalidateSessionDueToMissingProfile();
  }

  Future<UserModel?> _fetchUserProfile(String uid) async {
    try {
      final snapshot = await _users.doc(uid).get();

      if (!snapshot.exists) {
        return null;
      }

      return UserModel.fromFirestore(snapshot);
    } on FirebaseException {
      return null;
    } catch (_) {
      return null;
    }
  }

  String _mapFirebaseAuthError(FirebaseAuthException exception) {
    return UserMessages.auth(exception);
  }

  String _mapFirestoreError(FirebaseException exception) {
    return UserMessages.firestore(exception);
  }

  void _logStartupProfileCheck(String? documentPath, {required bool found}) {
    if (!AppEnvironment.isDev) {
      return;
    }

    if (documentPath == null) {
      debugPrint('[SAINTS Dev] Startup Firestore: sin Auth');
      return;
    }

    debugPrint(
      '[SAINTS Dev] Startup Firestore: $documentPath → '
      '${found ? "existe" : "no existe"}',
    );
  }

  void dispose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    _userController.close();
  }
}
