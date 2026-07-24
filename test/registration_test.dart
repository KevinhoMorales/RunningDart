import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_dart/models/membership_status.dart';
import 'package:running_dart/models/user_model.dart';
import 'package:running_dart/models/user_role.dart';
import 'package:running_dart/models/membership_modality.dart';
import 'package:running_dart/providers/auth_provider.dart';
import 'package:running_dart/services/auth_service.dart';
import 'package:running_dart/services/local_storage_service.dart';
import 'package:running_dart/services/mock_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // AuthProvider construye WatchSyncService, que registra un MethodChannel.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserModel.toFirestore', () {
    test('includes required fields for new registration', () {
      final user = UserModel(
        id: 'user-1',
        email: 'test@example.com',
        displayName: 'Test User',
        qrCode: 'RD-abc123',
        createdAt: DateTime(2026, 1, 15, 10, 30),
        isActive: true,
        role: UserRole.user,
      );

      final data = user.toFirestore();

      expect(
        data.keys,
        containsAll([
          'email',
          'displayName',
          'qrCode',
          'createdAt',
          'isActive',
          'role',
        ]),
      );
      expect(data['email'], 'test@example.com');
      expect(data['displayName'], 'Test User');
      expect(data['qrCode'], 'RD-abc123');
      expect(data['isActive'], isTrue);
      expect(data['role'], 'user');
      expect(data['createdAt'], isA<Timestamp>());
      expect(data.containsKey('photoUrl'), isFalse);
    });

    test('includes photoUrl when provided', () {
      final user = UserModel(
        id: 'user-1',
        email: 'test@example.com',
        displayName: 'Test User',
        qrCode: 'RD-abc123',
        createdAt: DateTime(2026, 1, 15),
        photoUrl: 'https://example.com/photo.jpg',
      );

      final data = user.toFirestore();

      expect(data['photoUrl'], 'https://example.com/photo.jpg');
    });
  });

  group('Registration flow', () {
    late AuthProvider authProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      authProvider = AuthProvider(MockAuthService(storage));
      await authProvider.initialize();
    });

    test('creates community user active immediately', () async {
      final success = await authProvider.register(
        email: 'community@example.com',
        password: 'secret123',
        profile: RegisterProfileData(
          displayName: 'Comunidad User',
          username: 'comunidaduser',
          whatsapp: '+593991234567',
          nationalIdLast4: '5678',
          birthDate: DateTime(1995, 5, 10),
          modality: MembershipModality.community,
          acceptedTerms: true,
        ),
      );

      expect(success, isTrue);
      expect(authProvider.user?.membershipModality,
          MembershipModality.community);
      expect(authProvider.user?.isMembershipPending, isFalse);
      expect(authProvider.user?.membershipStatus, MembershipStatus.active);
    });

    test('derives the username from the email when none was given', () async {
      final success = await authProvider.register(
        email: 'Kevin.Mora@example.com',
        password: 'secret123',
        profile: RegisterProfileData(
          displayName: 'Kevin Mora',
          username: '',
          whatsapp: '+593991234567',
          nationalIdLast4: '5678',
          birthDate: DateTime(1995, 5, 10),
          modality: MembershipModality.community,
          acceptedTerms: true,
        ),
      );

      expect(success, isTrue);
      expect(authProvider.user?.username, 'kevin.mora');
    });

    test('leaves the cooldown unstarted so the first change is free', () async {
      await authProvider.register(
        email: 'community@example.com',
        password: 'secret123',
        profile: RegisterProfileData(
          displayName: 'Comunidad User',
          username: 'comunidaduser',
          whatsapp: '+593991234567',
          nationalIdLast4: '5678',
          birthDate: DateTime(1995, 5, 10),
          modality: MembershipModality.community,
          acceptedTerms: true,
        ),
      );

      expect(authProvider.user?.usernameUpdatedAt, isNull);
    });

    test('creates pending user for paid modality', () async {
      final success = await authProvider.register(
        email: 'new@example.com',
        password: 'secret123',
        profile: RegisterProfileData(
          displayName: 'Nuevo Usuario',
          username: 'nuevousuario',
          whatsapp: '+593991234567',
          nationalIdLast4: '1234',
          birthDate: DateTime(1995, 5, 10),
          modality: MembershipModality.official,
          acceptedTerms: true,
        ),
      );

      expect(success, isTrue);
      expect(authProvider.canAccessApp, isTrue);
      expect(authProvider.user?.role, UserRole.user);
      expect(authProvider.user?.isActive, isTrue);
      expect(authProvider.user?.isMembershipPending, isTrue);
      expect(authProvider.user?.photoUrl, isNull);
      expect(authProvider.user?.email, 'new@example.com');
      expect(authProvider.user?.displayName, 'Nuevo Usuario');
      expect(authProvider.user?.qrCode, startsWith('RD-'));
    });
  });
}
