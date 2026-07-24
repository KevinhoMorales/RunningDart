import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/social_service.dart';

class SocialProvider extends ChangeNotifier {
  SocialProvider(this._socialService);

  final SocialService _socialService;

  StreamSubscription<Set<String>>? _followingSubscription;
  StreamSubscription<Set<String>>? _blockedSubscription;

  String? _userId;
  Set<String> _followingIds = {};
  Set<String> _blockedIds = {};

  Set<String> get followingIds => _followingIds;
  Set<String> get blockedIds => _blockedIds;

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
        notifyListeners();
      },
      onError: (_) {},
    );

    _blockedSubscription?.cancel();
    _blockedSubscription = _socialService.watchBlockedIds(userId).listen(
      (ids) {
        _blockedIds = ids;
        notifyListeners();
      },
      onError: (_) {},
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
