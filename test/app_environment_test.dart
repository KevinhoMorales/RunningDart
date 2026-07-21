import 'package:flutter_test/flutter_test.dart';
import 'package:running_dart/config/app_environment.dart';

void main() {
  test('defaults to production when APP_ENV is not set', () {
    expect(AppEnvironment.current, AppEnvironment.prod);
    expect(AppEnvironment.isProd, isTrue);
    expect(AppEnvironment.isDev, isFalse);
  });
}

// Run with:
// flutter test --dart-define=APP_ENV=dev test/app_environment_test.dart
