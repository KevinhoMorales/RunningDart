import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../models/user_role.dart';
import '../services/user_service.dart';

class AdminProvider extends ChangeNotifier {
  AdminProvider(this._userService);

  final UserServiceBase _userService;

  StreamSubscription<List<UserModel>>? _usersSubscription;

  List<UserModel> _users = [];
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isUpdating = false;
  String? _error;
  String? _errorDetail;

  List<UserModel> get users => _users;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  bool get isUpdating => _isUpdating;
  String? get error => _error;
  String? get errorDetail => _errorDetail;
  bool get isListening => _usersSubscription != null;

  List<UserModel> get filteredUsers =>
      UserService.filterUsers(_users, _searchQuery);

  static String _messageForLoadError(Object error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'Sin permiso para listar usuarios. Verifica que tu cuenta tenga '
          'role admin y que las reglas de Firestore estén publicadas.';
    }
    return 'No se pudieron cargar los usuarios.';
  }

  static String? _detailForLoadError(Object error) {
    if (kDebugMode) {
      return error.toString();
    }
    return null;
  }

  void startListening() {
    if (_usersSubscription != null) {
      return;
    }

    unawaited(_listenForUsers(showInitialLoading: _users.isEmpty));
  }

  Future<void> refresh() async {
    stopListening();
    return _listenForUsers(showInitialLoading: _users.isEmpty);
  }

  void retry() {
    unawaited(refresh());
  }

  Future<void> _listenForUsers({required bool showInitialLoading}) async {
    if (showInitialLoading) {
      _isLoading = true;
    }
    _error = null;
    _errorDetail = null;
    notifyListeners();

    final completer = Completer<void>();

    _usersSubscription = _userService.watchAllUsers().listen(
      (users) {
        _users = users;
        _isLoading = false;
        _error = null;
        _errorDetail = null;
        if (!completer.isCompleted) {
          completer.complete();
        }
        notifyListeners();
      },
      onError: (Object error) {
        _error = _messageForLoadError(error);
        _errorDetail = _detailForLoadError(error);
        _isLoading = false;
        if (!completer.isCompleted) {
          completer.complete();
        }
        notifyListeners();
      },
    );

    return completer.future;
  }

  void stopListening() {
    _usersSubscription?.cancel();
    _usersSubscription = null;
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) {
      return;
    }
    _searchQuery = query;
    notifyListeners();
  }

  Future<UserModel?> getUserById(String id) {
    return _userService.getUserById(id);
  }

  Future<bool> updateUserActive(String userId, bool isActive) async {
    _isUpdating = true;
    _error = null;
    notifyListeners();

    try {
      await _userService.setUserActive(userId, isActive);
      return true;
    } catch (_) {
      _error = 'No se pudo actualizar el estado del usuario.';
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  Future<bool> updateUserRole(
    String userId,
    UserRole role, {
    String? actingAdminId,
  }) async {
    if (actingAdminId != null && userId == actingAdminId) {
      _error = 'No puedes cambiar tu propio rol.';
      notifyListeners();
      return false;
    }

    _isUpdating = true;
    _error = null;
    notifyListeners();

    try {
      await _userService.setUserRole(userId, role);
      return true;
    } catch (_) {
      _error = 'No se pudo actualizar el rol del usuario.';
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  Future<bool> updateBusinessAssignment(
    String userId,
    String? businessId,
  ) async {
    _isUpdating = true;
    _error = null;
    notifyListeners();

    try {
      await _userService.setBusinessAssignment(userId, businessId);
      return true;
    } catch (_) {
      _error = 'No se pudo actualizar la asignación del negocio.';
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
