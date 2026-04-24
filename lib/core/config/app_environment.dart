enum AppEnvironment {
  local('local'),
  development('dev'),
  production('prod');

  const AppEnvironment(this.value);

  final String value;

  bool get isLocal => this == AppEnvironment.local;
  bool get isDevelopment => this == AppEnvironment.development;
  bool get isProduction => this == AppEnvironment.production;

  static AppEnvironment parse(String rawValue) {
    final normalized = rawValue.trim().toLowerCase();
    for (final environment in AppEnvironment.values) {
      if (environment.value == normalized) {
        return environment;
      }
    }

    throw StateError(
      'APP_ENV non valido: "$rawValue". Usa local, dev oppure prod.',
    );
  }
}
