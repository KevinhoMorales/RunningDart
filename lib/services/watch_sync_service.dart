import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/user_model.dart';
import '../models/watch_sync_state.dart';

class WatchSyncService {
  WatchSyncService({
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel(_channelName) {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static const _channelName = 'com.devlokos.runningdart/watch';

  final MethodChannel _channel;
  Future<void> Function()? _refreshHandler;

  void registerRefreshHandler(Future<void> Function() handler) {
    _refreshHandler = handler;
  }

  Future<void> syncUser(UserModel? user) async {
    if (!Platform.isIOS) {
      return;
    }

    final state = WatchSyncState.fromUser(user);

    try {
      await _channel.invokeMethod<void>(
        'updateContext',
        jsonEncode(state.toJson()),
      );
    } catch (error, stackTrace) {
      debugPrint('Watch sync failed: $error\n$stackTrace');
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'requestRefresh') {
      return;
    }

    final handler = _refreshHandler;
    if (handler == null) {
      return;
    }

    try {
      await handler();
    } catch (error, stackTrace) {
      debugPrint('Watch refresh handler failed: $error\n$stackTrace');
    }
  }
}
