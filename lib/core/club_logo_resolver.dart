import '../data/api_client.dart';
import 'app_supabase_config.dart';

const String kClubLogoStorageBucket = 'club-assets';

String? normalizeClubLogoStoragePath(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  return trimmed;
}

String buildClubLogoPublicUrl(
  String supabaseUrl,
  String storagePath, {
  String bucket = kClubLogoStorageBucket,
}) {
  final normalizedBaseUrl = supabaseUrl.endsWith('/')
      ? supabaseUrl
      : '$supabaseUrl/';
  final encodedPath = storagePath
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .map(Uri.encodeComponent)
      .join('/');

  return Uri.parse(normalizedBaseUrl)
      .resolve('storage/v1/object/public/$bucket/$encodedPath')
      .toString();
}

class ClubLogoResolver {
  ClubLogoResolver({
    AppSupabaseConfigRepository? configRepository,
  }) : _configRepository =
           configRepository ?? AppSupabaseConfigRepository.instance;

  static final ClubLogoResolver instance = ClubLogoResolver();

  final AppSupabaseConfigRepository _configRepository;
  final Map<String, String> _resolvedUrlsByStoragePath = {};

  Future<String?> resolveUrl({
    String? storagePath,
    String? fallbackUrl,
  }) async {
    final normalizedStoragePath = normalizeClubLogoStoragePath(storagePath);
    if (normalizedStoragePath == null) {
      return _normalizeFallbackUrl(fallbackUrl);
    }

    final cachedUrl = _resolvedUrlsByStoragePath[normalizedStoragePath];
    if (cachedUrl != null && cachedUrl.isNotEmpty) {
      return cachedUrl;
    }

    try {
      final config = await _configRepository.load();
      final resolvedUrl = buildClubLogoPublicUrl(
        config.url,
        normalizedStoragePath,
      );
      _resolvedUrlsByStoragePath[normalizedStoragePath] = resolvedUrl;
      return resolvedUrl;
    } on ApiException {
      return _normalizeFallbackUrl(fallbackUrl);
    }
  }

  void clearCache() {
    _resolvedUrlsByStoragePath.clear();
  }

  String? _normalizeFallbackUrl(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}
