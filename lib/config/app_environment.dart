enum AppEnvironment {
  dev('dev'),
  prod('prod');

  const AppEnvironment(this.name);

  final String name;

  static const _raw = String.fromEnvironment('APP_ENV', defaultValue: 'prod');

  static AppEnvironment get current {
    return switch (_raw.toLowerCase()) {
      'dev' || 'development' => AppEnvironment.dev,
      _ => AppEnvironment.prod,
    };
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
