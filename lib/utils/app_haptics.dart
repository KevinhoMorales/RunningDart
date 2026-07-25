import 'package:flutter/services.dart';

abstract final class AppHaptics {
  static Future<void> lightTap() => HapticFeedback.lightImpact();

  /// Para acciones que cierran un flujo: confirmar algo destructivo o soltar
  /// el gesto de refrescar.
  static Future<void> confirm() => HapticFeedback.mediumImpact();

  /// Para errores y avisos que el usuario no esperaba.
  static Future<void> alert() => HapticFeedback.heavyImpact();

  static VoidCallback? wrap(
    VoidCallback? callback, {
    Future<void> Function() feedback = lightTap,
  }) {
    if (callback == null) return null;
    return () {
      feedback();
      callback();
    };
  }

  static void Function(T value)? wrapValue<T>(
    void Function(T value)? callback, {
    Future<void> Function() feedback = lightTap,
  }) {
    if (callback == null) return null;
    return (value) {
      feedback();
      callback(value);
    };
  }

  static Future<T> Function() wrapFuture<T>(
    Future<T> Function() callback, {
    Future<void> Function() feedback = lightTap,
  }) {
    return () {
      feedback();
      return callback();
    };
  }
}
