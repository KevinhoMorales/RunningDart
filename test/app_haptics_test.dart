import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_dart/utils/app_haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final vibrations = <String>[];

  setUp(() {
    vibrations.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        vibrations.add(call.arguments as String? ?? 'standard');
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

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

    test('wrapFuture executes the original callback and returns its future',
        () async {
      final result = await AppHaptics.wrapFuture(() async => 'listo')();
      expect(result, 'listo');
    });

    test('each level asks the platform for a different intensity', () async {
      await AppHaptics.lightTap();
      await AppHaptics.confirm();
      await AppHaptics.alert();

      expect(vibrations, [
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.heavyImpact',
      ]);
    });

    test('wrap uses a light tap by default and honors the given level', () {
      AppHaptics.wrap(() {})?.call();
      AppHaptics.wrap(() {}, feedback: AppHaptics.confirm)?.call();
      AppHaptics.wrapValue<int>((_) {}, feedback: AppHaptics.alert)?.call(1);
      AppHaptics.wrapFuture(
        () async {},
        feedback: AppHaptics.confirm,
      )();

      expect(vibrations, [
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.heavyImpact',
        'HapticFeedbackType.mediumImpact',
      ]);
    });
  });
}
