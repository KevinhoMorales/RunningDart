import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

enum AppEnvironment {
  dev('dev'),
  prod('prod');

  const AppEnvironment(this.name);

  final String name;

  static const _compileTimeRaw = String.fromEnvironment('APP_ENV');

  static AppEnvironment? _resolved;
  static bool _initialized = false;

  static AppEnvironment _fromRaw(String raw) {
    return switch (raw.toLowerCase()) {
      'dev' || 'development' => AppEnvironment.dev,
      _ => AppEnvironment.prod,
    };
  }

  /// Resolves [current] from the app package/bundle id when [APP_ENV] was not
  /// passed at compile time (e.g. Android Studio builds without dart-defines).
  static Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    if (_compileTimeRaw.isNotEmpty) {
      _resolved = _fromRaw(_compileTimeRaw);
      return;
    }

    if (kIsWeb) {
      _resolved = AppEnvironment.prod;
      return;
    }

    try {
      final packageName = (await PackageInfo.fromPlatform()).packageName;
      _resolved = packageName.endsWith('.dev')
          ? AppEnvironment.dev
          : AppEnvironment.prod;
    } catch (_) {
      _resolved = AppEnvironment.prod;
    }
  }

  static AppEnvironment get current {
    if (_resolved != null) {
      return _resolved!;
    }
    if (_compileTimeRaw.isNotEmpty) {
      return _fromRaw(_compileTimeRaw);
    }
    return AppEnvironment.prod;
  }

  static bool get isDev => current == AppEnvironment.dev;

  static bool get isProd => current == AppEnvironment.prod;

  static String get displayName => isDev ? 'Desarrollo' : 'Producción';

  String get label => switch (this) {
        AppEnvironment.dev => 'Desarrollo',
        AppEnvironment.prod => 'Producción',
      };

  static String get appTitle => isDev ? 'SAINTS Dev' : 'SAINTS';
}
