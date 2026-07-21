import 'package:flutter_test/flutter_test.dart';
import 'package:running_dart/providers/app_update_provider.dart';
import 'package:running_dart/services/app_version_service.dart';

void main() {
  group('AppUpdateProvider', () {
    test('marks update required when remote version is higher', () async {
      final provider = AppUpdateProvider(
        versionService: _FakeAppVersionService(
          const AppUpdateStatus(
            requiresUpdate: true,
            currentVersion: '1.0.0',
            requiredVersion: '1.0.2',
          ),
        ),
      );

      await provider.checkForUpdate();

      expect(provider.isChecked, isTrue);
      expect(provider.requiresUpdate, isTrue);
      expect(provider.currentVersion, '1.0.0');
      expect(provider.requiredVersion, '1.0.2');
    });

    test('notRequired constructor skips remote check', () {
      final provider = AppUpdateProvider.notRequired(currentVersion: '1.0.0');

      expect(provider.isChecked, isTrue);
      expect(provider.requiresUpdate, isFalse);
      expect(provider.currentVersion, '1.0.0');
    });
  });
}

class _FakeAppVersionService implements AppVersionService {
  const _FakeAppVersionService(this.status);

  final AppUpdateStatus status;

  @override
  Future<AppUpdateStatus> checkForRequiredUpdate() async => status;
}
