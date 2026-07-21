import 'package:flutter_test/flutter_test.dart';
import 'package:running_dart/utils/version_utils.dart';

void main() {
  group('VersionUtils', () {
    test('compare orders semantic versions', () {
      expect(VersionUtils.compare('1.0.0', '1.0.2'), lessThan(0));
      expect(VersionUtils.compare('1.0.2', '1.0.0'), greaterThan(0));
      expect(VersionUtils.compare('1.0.0', '1.0.0'), 0);
    });

    test('isUpdateRequired ignores build suffix', () {
      expect(
        VersionUtils.isUpdateRequired(
          currentVersion: '1.0.0+100',
          requiredVersion: '1.0.2',
        ),
        isTrue,
      );
      expect(
        VersionUtils.isUpdateRequired(
          currentVersion: '1.0.2+120',
          requiredVersion: '1.0.2',
        ),
        isFalse,
      );
    });

    test('isUpdateRequired handles partial versions', () {
      expect(
        VersionUtils.isUpdateRequired(
          currentVersion: '1.0',
          requiredVersion: '1.0.1',
        ),
        isTrue,
      );
    });
  });
}
