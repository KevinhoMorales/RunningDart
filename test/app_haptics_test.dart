import 'package:flutter_test/flutter_test.dart';
import 'package:running_dart/utils/app_haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppHaptics', () {
    test('wrap returns null for null callback', () {
      expect(AppHaptics.wrap(null), isNull);
    });

    test('wrapValue returns null for null callback', () {
      expect(AppHaptics.wrapValue<int>(null), isNull);
    });

    test('wrap executes the original callback', () {
      var called = false;
      AppHaptics.wrap(() => called = true)?.call();
      expect(called, isTrue);
    });

    test('wrapValue executes the original callback with value', () {
      int? received;
      AppHaptics.wrapValue<int>((value) => received = value)?.call(42);
      expect(received, 42);
    });
  });
}
