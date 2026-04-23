import '../data/api_client.dart';

class AppSupabaseConfig {
  const AppSupabaseConfig({
    required this.url,
    required this.anonKey,
    required this.localRealtimeFallbackEnabled,
  });

  final String url;
  final String anonKey;
  final bool localRealtimeFallbackEnabled;

  bool get isValid => url.trim().isNotEmpty && anonKey.trim().isNotEmpty;
}

class AppSupabaseConfigRepository {
  AppSupabaseConfigRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.shared;

  static final AppSupabaseConfigRepository instance =
      AppSupabaseConfigRepository();

  static const String _configuredUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _configuredAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  final ApiClient _apiClient;

  AppSupabaseConfig? _cachedConfig;

  Future<AppSupabaseConfig> load() async {
    final cached = _cachedConfig;
    if (cached != null && cached.isValid) {
      return cached;
    }

    final configuredUrl = _configuredUrl.trim();
    final configuredAnonKey = _configuredAnonKey.trim();
    if (configuredUrl.isNotEmpty && configuredAnonKey.isNotEmpty) {
      final config = AppSupabaseConfig(
        url: configuredUrl,
        anonKey: configuredAnonKey,
        localRealtimeFallbackEnabled: false,
      );
      _cachedConfig = config;
      return config;
    }

    final response = await _apiClient.get('/auth/public-config');
    final responseMap = Map<String, dynamic>.from(response as Map);
    final rawSupabase = Map<String, dynamic>.from(
      responseMap['supabase'] as Map? ?? const <String, dynamic>{},
    );
    final rawRealtime = Map<String, dynamic>.from(
      responseMap['realtime'] as Map? ?? const <String, dynamic>{},
    );

    final config = AppSupabaseConfig(
      url: rawSupabase['url']?.toString().trim() ?? '',
      anonKey: rawSupabase['anonKey']?.toString().trim() ?? '',
      localRealtimeFallbackEnabled: rawRealtime['localFallbackEnabled'] == true,
    );

    if (!config.isValid) {
      throw const ApiException(
        'Configurazione Supabase non disponibile per il client realtime.',
      );
    }

    _cachedConfig = config;
    return config;
  }

  void clearCache() {
    _cachedConfig = null;
  }
}
