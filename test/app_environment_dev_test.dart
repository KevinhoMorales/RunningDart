import 'package:flutter_test/flutter_test.dart';
import 'package:running_dart/config/app_environment.dart';

void main() {
  final compiledWithDev =
      const String.fromEnvironment('APP_ENV', defaultValue: 'prod') == 'dev';

  test(
    'uses development when APP_ENV=dev',
    () {
      expect(AppEnvironment.current, AppEnvironment.dev);
      expect(AppEnvironment.isDev, isTrue);
      expect(AppEnvironment.isProd, isFalse);
      expect(AppEnvironment.appTitle, 'SAINTS Dev');
    },
    skip: compiledWithDev
        ? false
        : 'Run with: flutter test --dart-define=APP_ENV=dev test/app_environment_dev_test.dart',
  );
}
