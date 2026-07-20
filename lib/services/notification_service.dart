import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

class NotificationService {
  NotificationService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  void Function(String route)? onNavigate;

  bool _initialized = false;
  bool _isSubscribed = false;
  bool _pushEnabled = true;

  bool get pushEnabled => _pushEnabled;

  static String? routeFromMessageData(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    final id = data['id']?.toString();
    if (id == null || id.isEmpty) {
      return null;
    }

    return switch (type) {
      'business' => '/business/$id',
      'news' => '/news/$id',
      _ => null,
    };
  }

  Future<void> initialize(SharedPreferences prefs) async {
    if (_initialized) {
      return;
    }

    _pushEnabled =
        prefs.getBool(AppConstants.pushNotificationsEnabledKey) ?? true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    const channel = AndroidNotificationChannel(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      description: AppConstants.notificationChannelDescription,
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _requestPermissions();

    _initialized = true;
  }

  Future<void> _requestPermissions() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  void bindRouterHandlers() {
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpened);
  }

  Future<void> handleInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    if (message != null) {
      _navigateFromMessage(message);
    }
  }

  Future<void> setPushEnabled(
    bool enabled, {
    required SharedPreferences prefs,
    UserModel? user,
  }) async {
    _pushEnabled = enabled;
    await prefs.setBool(AppConstants.pushNotificationsEnabledKey, enabled);
    await syncForUser(user);
  }

  Future<void> syncForUser(UserModel? user) async {
    final shouldSubscribe =
        _pushEnabled && user != null && user.isAccountActive;

    if (shouldSubscribe) {
      if (!_isSubscribed) {
        await _messaging.subscribeToTopic(AppConstants.fcmTopicNewBusinesses);
        await _messaging.subscribeToTopic(AppConstants.fcmTopicNewEvents);
        _isSubscribed = true;
      }
      return;
    }

    await unsubscribeAll();
  }

  Future<void> unsubscribeAll() async {
    await _messaging.unsubscribeFromTopic(AppConstants.fcmTopicNewBusinesses);
    await _messaging.unsubscribeFromTopic(AppConstants.fcmTopicNewEvents);
    _isSubscribed = false;
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) {
      return;
    }

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _navigateFromData(data);
    } catch (error, stackTrace) {
      debugPrint('Invalid notification payload: $error\n$stackTrace');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) {
      return;
    }

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.notificationChannelId,
          AppConstants.notificationChannelName,
          channelDescription: AppConstants.notificationChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _handleMessageOpened(RemoteMessage message) {
    _navigateFromMessage(message);
  }

  void _navigateFromMessage(RemoteMessage message) {
    _navigateFromData(message.data);
  }

  void _navigateFromData(Map<String, dynamic> data) {
    final route = routeFromMessageData(data);
    if (route != null) {
      onNavigate?.call(route);
    }
  }
}
