import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_environment.dart';
import '../config/firebase_paths.dart';
import '../firebase_options.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await AppEnvironment.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

class NotificationService {
  NotificationService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
    FirebaseFirestore? firestore,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final FirebaseFirestore _firestore;

  SharedPreferences? _prefs;
  String? _activeUserId;
  String? _registeredToken;
  bool _tokenRefreshBound = false;

  void Function(String route)? onNavigate;

  bool _initialized = false;
  bool _isSubscribed = false;
  bool _pushEnabled = false;

  bool get pushEnabled => _pushEnabled;

  static String? routeFromMessageData(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    final id = data['id']?.toString();

    return switch (type) {
      'business' when id != null && id.isNotEmpty => '/business/$id',
      'news' when id != null && id.isNotEmpty => '/news/$id',
      'activity' when id != null && id.isNotEmpty => '/activities/$id',
      'activity_checkin' when id != null && id.isNotEmpty =>
        '/activities/$id/check-in',
      'challenge' || 'league' => '/league',
      _ => null,
    };
  }

  Future<void> initialize(SharedPreferences prefs) async {
    if (_initialized) {
      return;
    }

    _prefs = prefs;
    _pushEnabled =
        prefs.getBool(AppConstants.pushNotificationsEnabledKey) ?? false;

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

    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    final settings = await _messaging.requestPermission(
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

    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  void bindRouterHandlers() {
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpened);
    _bindTokenRefresh();
  }

  void _bindTokenRefresh() {
    if (_tokenRefreshBound) return;
    _tokenRefreshBound = true;
    _messaging.onTokenRefresh.listen((token) async {
      final userId = _activeUserId;
      if (!_pushEnabled || userId == null) return;
      await _persistToken(userId: userId, token: token);
    });
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

    if (enabled) {
      await requestPermissions();
    }

    await syncForUser(user);
  }

  Future<void> syncForUser(UserModel? user) async {
    final shouldSubscribe =
        _pushEnabled && user != null && user.isAccountActive;

    if (shouldSubscribe) {
      _activeUserId = user.id;
      if (!_isSubscribed) {
        await _unsubscribeLegacyTopics();
        for (final topic in _currentTopics) {
          await _messaging.subscribeToTopic(topic);
        }
        _isSubscribed = true;
      }
      await _registerDeviceToken(user.id);
      return;
    }

    await _clearDeviceToken();
    await unsubscribeAll();
    _activeUserId = null;
  }

  Future<void> unsubscribeAll() async {
    for (final topic in _currentTopics) {
      await _messaging.unsubscribeFromTopic(topic);
    }
    await _unsubscribeLegacyTopics();
    _isSubscribed = false;
  }

  List<String> get _currentTopics {
    final environment = AppEnvironment.current;
    return [
      AppConstants.fcmTopicNewBusinesses(environment),
      AppConstants.fcmTopicNewEvents(environment),
      AppConstants.fcmTopicClubActivities(environment),
    ];
  }

  /// Un dispositivo que ya tenía la app instalada sigue suscrito al topic sin
  /// sufijo de ambiente, así que hay que sacarlo o recibiría avisos de dev.
  /// Basta una vez por instalación: los topics nuevos nunca vuelven a los viejos.
  Future<void> _unsubscribeLegacyTopics() async {
    final prefs = _prefs;
    if (prefs?.getBool(AppConstants.legacyFcmTopicsClearedKey) ?? false) {
      return;
    }

    for (final topic in AppConstants.legacyFcmTopics) {
      try {
        await _messaging.unsubscribeFromTopic(topic);
      } catch (error) {
        debugPrint('No se pudo desuscribir del topic antiguo $topic: $error');
        return;
      }
    }

    await prefs?.setBool(AppConstants.legacyFcmTopicsClearedKey, true);
  }

  Future<void> _registerDeviceToken(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;
      await _persistToken(userId: userId, token: token);
    } catch (error, stackTrace) {
      debugPrint('FCM token register failed: $error\n$stackTrace');
    }
  }

  Future<void> _persistToken({
    required String userId,
    required String token,
  }) async {
    final previous = _registeredToken;
    final ref = FirebasePaths.collection(_firestore, 'users').doc(userId);
    final updates = <String, dynamic>{
      'fcmTokens': FieldValue.arrayUnion([token]),
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    };
    if (previous != null && previous.isNotEmpty && previous != token) {
      updates['fcmTokens'] = FieldValue.arrayUnion([token]);
      // Remove stale token in a follow-up so arrayUnion/remove don't clash.
      await ref.set(updates, SetOptions(merge: true));
      await ref.update({
        'fcmTokens': FieldValue.arrayRemove([previous]),
      });
    } else {
      await ref.set(updates, SetOptions(merge: true));
    }
    _registeredToken = token;
  }

  Future<void> _clearDeviceToken() async {
    final userId = _activeUserId;
    final token = _registeredToken;
    if (userId == null || token == null || token.isEmpty) {
      _registeredToken = null;
      return;
    }
    try {
      await FirebasePaths.collection(_firestore, 'users').doc(userId).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });
    } catch (error, stackTrace) {
      debugPrint('FCM token clear failed: $error\n$stackTrace');
    }
    _registeredToken = null;
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
