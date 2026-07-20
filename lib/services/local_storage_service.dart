import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';

class LocalStorageService {
  LocalStorageService(this._prefs);

  final SharedPreferences _prefs;

  static const _usersKey = 'mock_users';
  static const _currentUserIdKey = 'current_user_id';

  Future<void> saveUser(UserModel user) async {
    final users = await getUsers();
    final index = users.indexWhere((u) => u.id == user.id);
    if (index >= 0) {
      users[index] = user;
    } else {
      users.add(user);
    }
    await _prefs.setString(
      _usersKey,
      jsonEncode(users.map((u) => u.toJson()).toList()),
    );
  }

  Future<List<UserModel>> getUsers() async {
    final raw = _prefs.getString(_usersKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((item) => UserModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<UserModel?> getUserByEmail(String email) async {
    final users = await getUsers();
    try {
      return users.firstWhere(
        (user) => user.email.toLowerCase() == email.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> setCurrentUserId(String userId) async {
    await _prefs.setString(_currentUserIdKey, userId);
  }

  Future<UserModel?> getCurrentUser() async {
    final userId = _prefs.getString(_currentUserIdKey);
    if (userId == null) {
      return null;
    }
    final users = await getUsers();
    try {
      return users.firstWhere((user) => user.id == userId);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() async {
    await _prefs.remove(_currentUserIdKey);
  }
}
