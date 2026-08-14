import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/membership_modality.dart';
import '../models/membership_status.dart';
import '../models/page_result.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import '../services/user_service.dart';

enum AdminUserFilter {
  all,
  pending,
  activeMembers,
  operators,
  users,
  members,
  admins,
  coaches,
  inactive;

  String get label => switch (this) {
        AdminUserFilter.all => 'Todos los usuarios',
        AdminUserFilter.pending => 'Solicitudes pendientes',
        AdminUserFilter.activeMembers => 'Miembros activos',
        AdminUserFilter.operators => 'Operadores de marcas',
        AdminUserFilter.users => 'Usuarios',
        AdminUserFilter.members => 'Miembros',
        AdminUserFilter.admins => 'Administradores',
        AdminUserFilter.coaches => 'Coach',
        AdminUserFilter.inactive => 'Cuentas inactivas',
      };

  String get chipLabel => switch (this) {
        AdminUserFilter.all => 'Todos',
        AdminUserFilter.pending => 'Pendientes',
        AdminUserFilter.activeMembers => 'Memb. activos',
        AdminUserFilter.operators => 'Operadores',
        AdminUserFilter.users => 'Usuarios',
        AdminUserFilter.members => 'Miembros',
        AdminUserFilter.admins => 'Admins',
        AdminUserFilter.coaches => 'Coach',
        AdminUserFilter.inactive => 'Inactivos',
      };
}

class AdminProvider extends ChangeNotifier {
  AdminProvider(this._userService);

  final UserServiceBase _userService;

  StreamSubscription<PageResult<UserModel>>? _usersSubscription;

  List<UserModel> _liveUsers = [];
  List<UserModel> _olderUsers = [];
  Object? _nextCursor;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  int _generation = 0;

  String _searchQuery = '';
  AdminUserFilter _userFilter = AdminUserFilter.all;
  bool _isLoading = false;
  bool _isUpdating = false;
  String? _error;
  String? _errorDetail;

  List<UserModel> get users {
    final byId = <String, UserModel>{};
    for (final user in _olderUsers) {
      byId[user.id] = user;
    }
    for (final user in _liveUsers) {
      byId[user.id] = user;
    }
    return UserService.sortUsersForAdmin(byId.values.toList());
  }

  String get searchQuery => _searchQuery;
  AdminUserFilter get userFilter => _userFilter;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  bool get isUpdating => _isUpdating;
  String? get error => _error;
  String? get errorDetail => _errorDetail;
  bool get isListening => _usersSubscription != null;

  List<UserModel> get filteredUsers {
    final all = users;
    final filtered = switch (_userFilter) {
      AdminUserFilter.all => all,
      AdminUserFilter.pending => all
          .where((u) => u.membershipStatus == MembershipStatus.pending)
          .toList(),
      AdminUserFilter.activeMembers => all
          .where(
            (u) =>
                u.isActive &&
                u.membershipStatus == MembershipStatus.active &&
                u.role.isMember,
          )
          .toList(),
      AdminUserFilter.operators =>
        all.where((u) => u.isBusinessOperator).toList(),
      AdminUserFilter.users =>
        all.where((u) => u.role.isUser).toList(),
      AdminUserFilter.members =>
        all.where((u) => u.role.isMember).toList(),
      AdminUserFilter.admins =>
        all.where((u) => u.role.isAdmin).toList(),
      AdminUserFilter.coaches =>
        all.where((u) => u.role.isCoach).toList(),
      AdminUserFilter.inactive =>
        all.where((u) => !u.isActive).toList(),
    };
    return UserService.filterUsers(filtered, _searchQuery);
  }

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

    unawaited(_listenForUsers(showInitialLoading: users.isEmpty));
  }

  Future<void> refresh() async {
    stopListening();
    _generation++;
    _liveUsers = [];
    _olderUsers = [];
    _nextCursor = null;
    _hasMore = true;
    _isLoadingMore = false;
    return _listenForUsers(showInitialLoading: users.isEmpty);
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

    _usersSubscription = _userService.watchUsers().listen(
      (page) {
        _liveUsers = page.items;
        if (_olderUsers.isEmpty) {
          _nextCursor = page.cursor;
          _hasMore = page.hasMore;
        } else {
          final liveIds = page.items.map((u) => u.id).toSet();
          _olderUsers =
              _olderUsers.where((u) => !liveIds.contains(u.id)).toList();
        }
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

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore || _isLoading || _nextCursor == null) {
      return;
    }

    final generation = _generation;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _userService.fetchUsersPage(startAfter: _nextCursor);
      if (generation != _generation) {
        return;
      }
      final known = <String>{
        for (final u in _liveUsers) u.id,
        for (final u in _olderUsers) u.id,
      };
      final fresh = page.items.where((u) => !known.contains(u.id)).toList();
      _olderUsers = [..._olderUsers, ...fresh];
      _nextCursor = page.cursor;
      _hasMore = page.hasMore;
    } catch (error) {
      if (generation != _generation) {
        return;
      }
      debugPrint('No se pudieron cargar más usuarios: $error');
    } finally {
      if (generation == _generation) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
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

  void setUserFilter(AdminUserFilter filter) {
    if (_userFilter == filter) {
      return;
    }
    _userFilter = filter;
    notifyListeners();
  }

  void clearUserFilter() {
    setUserFilter(AdminUserFilter.all);
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
      _error = 'No se pudo actualizar la asignación de la marca.';
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  Future<bool> approveMembership(String userId) async {
    _isUpdating = true;
    _error = null;
    notifyListeners();

    try {
      await _userService.approveMembership(userId);
      return true;
    } catch (_) {
      _error = 'No se pudo aprobar la membresía.';
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  Future<bool> rejectMembership(String userId) async {
    _isUpdating = true;
    _error = null;
    notifyListeners();

    try {
      await _userService.rejectMembership(userId);
      return true;
    } catch (_) {
      _error = 'No se pudo rechazar la solicitud.';
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  Future<bool> updateMembershipProfile({
    required String userId,
    required MembershipModality modality,
    required MembershipStatus status,
    DateTime? expiresAt,
    String? whatsapp,
    String? nationalIdLast4,
    DateTime? birthDate,
    String? internalNotes,
  }) async {
    _isUpdating = true;
    _error = null;
    notifyListeners();

    try {
      await _userService.updateMembershipProfile(
        id: userId,
        modality: modality,
        status: status,
        expiresAt: expiresAt,
        activatedAt: status == MembershipStatus.active ? DateTime.now() : null,
        whatsapp: whatsapp,
        nationalIdLast4: nationalIdLast4,
        birthDate: birthDate,
        internalNotes: internalNotes,
      );
      return true;
    } catch (_) {
      _error = 'No se pudo actualizar la membresía.';
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
