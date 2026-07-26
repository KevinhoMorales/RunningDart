import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/public_profile.dart';
import '../services/social_service.dart';

class SocialProvider extends ChangeNotifier {
  SocialProvider(this._socialService);

  final SocialService _socialService;

  StreamSubscription<Set<String>>? _followingSubscription;
  StreamSubscription<Set<String>>? _blockedSubscription;

  String? _userId;
  Set<String> _followingIds = {};
  Set<String> _blockedIds = {};

  String? _followingError;
  String? _blockedError;

  Set<String> get followingIds => _followingIds;
  Set<String> get blockedIds => _blockedIds;

  String? get followingError => _followingError;

  /// Si esto no es nulo, [isBlocked] no es de fiar y la UI debe decirlo en vez
  /// de comportarse como si no hubiera nadie bloqueado.
  String? get blockedError => _blockedError;

  bool isFollowing(String userId) => _followingIds.contains(userId);
  bool isBlocked(String userId) => _blockedIds.contains(userId);

  void start(String userId) {
    if (_userId == userId && _followingSubscription != null) {
      return;
    }
    _userId = userId;

    _followingSubscription?.cancel();
    _followingSubscription = _socialService.watchFollowingIds(userId).listen(
      (ids) {
        _followingIds = ids;
        _followingError = null;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('No se pudo cargar a quién sigues: $error');
        _followingError = 'No pudimos cargar a quién sigues.';
        notifyListeners();
      },
    );

    _blockedSubscription?.cancel();
    _blockedSubscription = _socialService.watchBlockedIds(userId).listen(
      (ids) {
        _blockedIds = ids;
        _blockedError = null;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('No se pudo cargar tu lista de bloqueos: $error');
        _blockedError = 'No pudimos cargar tu lista de bloqueos.';
        notifyListeners();
      },
    );
  }

  Future<void> toggleFollow(String targetUserId) async {
    if (isFollowing(targetUserId)) {
      await unfollow(targetUserId);
    } else {
      await follow(targetUserId);
    }
  }

  Future<void> follow(String targetUserId) async {
    final userId = _userId;
    if (userId == null || userId == targetUserId) {
      return;
    }
    await _socialService.follow(followerId: userId, followedId: targetUserId);
  }

  Future<void> unfollow(String targetUserId) async {
    final userId = _userId;
    if (userId == null) {
      return;
    }
    await _socialService.unfollow(followerId: userId, followedId: targetUserId);
  }

  Future<void> blockUser(String targetUserId) async {
    final userId = _userId;
    if (userId == null || userId == targetUserId) {
      return;
    }
    await _socialService.blockUser(blockerId: userId, blockedId: targetUserId);

    // Seguir a alguien a quien acabas de bloquear no tiene sentido, y su perfil
    // seguiría apareciendo en "Para ti".
    if (isFollowing(targetUserId)) {
      await _socialService.unfollow(
        followerId: userId,
        followedId: targetUserId,
      );
    }
  }

  /// Perfiles públicos de las personas bloqueadas, para poder desbloquearlas.
  Future<List<PublicProfile>> blockedProfiles() {
    return _socialService.getPublicProfilesByIds(
      _blockedIds.toList(growable: false),
    );
  }

  Future<void> unblockUser(String targetUserId) async {
    final userId = _userId;
    if (userId == null) {
      return;
    }
    await _socialService.unblockUser(blockerId: userId, blockedId: targetUserId);
  }

  @override
  void dispose() {
    _followingSubscription?.cancel();
    _blockedSubscription?.cancel();
    super.dispose();
  }
}
