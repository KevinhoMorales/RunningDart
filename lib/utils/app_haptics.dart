import 'package:flutter/services.dart';

abstract final class AppHaptics {
  static Future<void> lightTap() => HapticFeedback.lightImpact();

  static VoidCallback? wrap(VoidCallback? callback) {
    if (callback == null) return null;
    return () {
      lightTap();
      callback();
    };
  }

  static void Function(T value)? wrapValue<T>(void Function(T value)? callback) {
    if (callback == null) return null;
    return (value) {
      lightTap();
      callback(value);
    };
  }
}
