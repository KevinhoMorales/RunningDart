import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:running_dart/models/membership_modality.dart';
import 'package:running_dart/models/membership_status.dart';
import 'package:running_dart/models/user_model.dart';
import 'package:running_dart/models/user_role.dart';
import 'package:running_dart/providers/notification_preferences_provider.dart';
import 'package:running_dart/utils/constants.dart';

UserModel _sampleUser() {
  return UserModel(
    id: 'user-notifications',
    email: 'notify@test.com',
    displayName: 'Notify User',
    qrCode: 'RD-notify',
    createdAt: DateTime(2026, 1, 1),
    isActive: true,
    role: UserRole.member,
    membershipModality: MembershipModality.community,
    membershipStatus: MembershipStatus.active,
  );
}

void main() {
  group('NotificationPreferencesProvider', () {
    test('defaults to disabled push and incomplete onboarding', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final provider = NotificationPreferencesProvider.test(prefs);

      expect(provider.enabled, isFalse);
      expect(provider.onboardingCompleted, isFalse);
      expect(provider.onboardingPending, isFalse);
    });

    test('markOnboardingPending sets pending flag', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final provider = NotificationPreferencesProvider.test(prefs);

      await provider.markOnboardingPending();

      expect(provider.onboardingPending, isTrue);
      expect(
        prefs.getBool(AppConstants.notificationsOnboardingPendingKey),
        isTrue,
      );
    });

    test('completeOnboarding with enabled false clears pending', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final provider = NotificationPreferencesProvider.test(prefs);

      await provider.markOnboardingPending();
      await provider.completeOnboarding(enabled: false);

      expect(provider.onboardingPending, isFalse);
      expect(provider.onboardingCompleted, isTrue);
      expect(provider.enabled, isFalse);
      expect(
        prefs.getBool(AppConstants.notificationsOnboardingCompletedKey),
        isTrue,
      );
    });

    test('completeOnboarding with enabled true persists preference', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final provider = NotificationPreferencesProvider.test(prefs);

      await provider.markOnboardingPending();
      await provider.completeOnboarding(
        enabled: true,
        user: _sampleUser(),
      );

      expect(provider.onboardingPending, isFalse);
      expect(provider.onboardingCompleted, isTrue);
      expect(provider.enabled, isTrue);
      expect(
        prefs.getBool(AppConstants.pushNotificationsEnabledKey),
        isTrue,
      );
    });
  });
}
