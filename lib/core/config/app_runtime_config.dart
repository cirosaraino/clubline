import 'app_environment.dart';

class AppRuntimeConfig {
  AppRuntimeConfig._({
    required this.environment,
    required this.apiBaseUrl,
    required this.realtimeTransport,
    required this.supabaseUrlOverride,
    required this.supabaseAnonKeyOverride,
  });

  static const String _configuredEnvironment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'local',
  );
  static const String _configuredApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );
  static const String _configuredRealtimeTransport = String.fromEnvironment(
    'REALTIME_TRANSPORT',
    defaultValue: 'supabase',
  );
  static const String _configuredSupabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
  );
  static const String _configuredSupabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
  static const String _defaultLocalBackendUrl = 'http://127.0.0.1:3001/api';

  static final AppRuntimeConfig instance = AppRuntimeConfig._resolve();

  final AppEnvironment environment;
  final String apiBaseUrl;
  final String realtimeTransport;
  final String? supabaseUrlOverride;
  final String? supabaseAnonKeyOverride;

  bool get hasSupabaseOverride =>
      (supabaseUrlOverride?.isNotEmpty ?? false) &&
      (supabaseAnonKeyOverride?.isNotEmpty ?? false);

  static AppRuntimeConfig _resolve() {
    final environment = AppEnvironment.parse(_configuredEnvironment);
    final apiBaseUrl = _resolveApiBaseUrl(environment);
    final realtimeTransport = _resolveRealtimeTransport();
    final supabaseUrlOverride = _normalizeOptional(_configuredSupabaseUrl);
    final supabaseAnonKeyOverride = _normalizeOptional(
      _configuredSupabaseAnonKey,
    );

    if (!_isAbsoluteHttpUrl(apiBaseUrl)) {
      throw StateError(
        'API_BASE_URL non valido: "$apiBaseUrl". Usa un URL assoluto http/https che punti al backend Clubline.',
      );
    }

    if ((supabaseUrlOverride == null) != (supabaseAnonKeyOverride == null)) {
      throw StateError(
        'SUPABASE_URL e SUPABASE_ANON_KEY devono essere definiti insieme oppure omessi.',
      );
    }

    if (supabaseUrlOverride != null &&
        !_isAbsoluteHttpUrl(supabaseUrlOverride)) {
      throw StateError('SUPABASE_URL non valido: "$supabaseUrlOverride".');
    }

    if (environment.isProduction && _isLocalUrl(apiBaseUrl)) {
      throw StateError(
        'APP_ENV=prod non puo usare un API_BASE_URL locale: $apiBaseUrl',
      );
    }

    return AppRuntimeConfig._(
      environment: environment,
      apiBaseUrl: apiBaseUrl,
      realtimeTransport: realtimeTransport,
      supabaseUrlOverride: supabaseUrlOverride,
      supabaseAnonKeyOverride: supabaseAnonKeyOverride,
    );
  }

  static String _resolveApiBaseUrl(AppEnvironment environment) {
    final configured = _normalizeOptional(_configuredApiBaseUrl);
    if (configured != null) {
      return _trimTrailingSlash(configured);
    }

    if (environment.isLocal || environment.isDevelopment) {
      return _defaultLocalBackendUrl;
    }

    throw StateError(
      'API_BASE_URL mancante per l ambiente corrente. Usa i runner in scripts/flutter/ oppure passa --dart-define-from-file.',
    );
  }

  static String _resolveRealtimeTransport() {
    final configured = _configuredRealtimeTransport.trim().toLowerCase();
    if (configured == 'supabase' || configured == 'local') {
      return configured;
    }

    throw StateError(
      'REALTIME_TRANSPORT non valido: "$_configuredRealtimeTransport". Usa supabase oppure local.',
    );
  }

  static String? _normalizeOptional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _trimTrailingSlash(String value) {
    if (!value.endsWith('/')) {
      return value;
    }

    return value.substring(0, value.length - 1);
  }

  static bool _isLocalUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) {
      return false;
    }

    final host = uri.host.trim().toLowerCase();
    return host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0';
  }

  static bool _isAbsoluteHttpUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }
}
