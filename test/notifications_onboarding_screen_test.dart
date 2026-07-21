import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:running_dart/models/membership_modality.dart';
import 'package:running_dart/models/membership_status.dart';
import 'package:running_dart/models/user_model.dart';
import 'package:running_dart/models/user_role.dart';
import 'package:running_dart/providers/auth_provider.dart';
import 'package:running_dart/providers/notification_preferences_provider.dart';
import 'package:running_dart/screens/onboarding/notifications_onboarding_screen.dart';
import 'package:running_dart/services/auth_service.dart';
import 'package:running_dart/utils/constants.dart';

class _OnboardingAuthService implements AuthService {
  static final UserModel user = UserModel(
    id: 'onboarding-user',
    email: 'onboarding@test.com',
    displayName: 'Onboarding User',
    qrCode: 'RD-onboarding',
    createdAt: DateTime(2026, 1, 1),
    isActive: true,
    role: UserRole.member,
    membershipModality: MembershipModality.community,
    membershipStatus: MembershipStatus.active,
  );

  @override
  Stream<UserModel?> get userChanges => Stream.value(user);

  @override
  Future<UserModel?> getCurrentUser() async => user;

  @override
  Future<UserModel?> resolveStartupSession() async => user;

  @override
  Future<UserModel?> refreshCurrentUser() async => user;

  @override
  Future<UserModel> register({
    required String email,
    required String password,
    required RegisterProfileData profile,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> deleteAccount() async {}
}

Future<void> _pumpOnboarding(
  WidgetTester tester, {
  required AuthProvider authProvider,
  required NotificationPreferencesProvider notificationPreferences,
  required GoRouter router,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: notificationPreferences),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  router.go('/onboarding/notifications');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('NotificationsOnboardingScreen shows benefits and actions', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final authProvider = AuthProvider(_OnboardingAuthService());
    await authProvider.initialize();
    final notificationPreferences = NotificationPreferencesProvider.test(prefs);
    await notificationPreferences.markOnboardingPending();

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/onboarding/notifications',
          builder: (context, state) => const NotificationsOnboardingScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
      ],
    );

    await _pumpOnboarding(
      tester,
      authProvider: authProvider,
      notificationPreferences: notificationPreferences,
      router: router,
    );

    expect(find.text('Mantente al día con SAINTS'), findsOneWidget);
    expect(find.text('Activar notificaciones'), findsOneWidget);
    expect(find.text('Ahora no'), findsOneWidget);
    expect(find.textContaining('nueva marca aliada'), findsOneWidget);
  });

  testWidgets('tap Ahora no completes onboarding with push disabled', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final authProvider = AuthProvider(_OnboardingAuthService());
    await authProvider.initialize();
    final notificationPreferences = NotificationPreferencesProvider.test(prefs);
    await notificationPreferences.markOnboardingPending();

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/onboarding/notifications',
          builder: (context, state) => const NotificationsOnboardingScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
      ],
    );

    await _pumpOnboarding(
      tester,
      authProvider: authProvider,
      notificationPreferences: notificationPreferences,
      router: router,
    );

    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();

    expect(notificationPreferences.onboardingCompleted, isTrue);
    expect(notificationPreferences.onboardingPending, isFalse);
    expect(notificationPreferences.enabled, isFalse);
    expect(
      prefs.getBool(AppConstants.pushNotificationsEnabledKey),
      isFalse,
    );
  });
}
