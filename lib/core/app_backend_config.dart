class AppBackendConfig {
  const AppBackendConfig._();

  static const String _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    final configured = _configuredBaseUrl.trim();
    if (configured.isNotEmpty) {
      return _trimTrailingSlash(configured);
    }

    final baseUri = Uri.base;
    final isWebOrigin = (baseUri.scheme == 'http' || baseUri.scheme == 'https') &&
        baseUri.host.isNotEmpty;

    if (isWebOrigin) {
      return _trimTrailingSlash(baseUri.resolve('/api').toString());
    }

    return 'http://localhost:3001/api';
  }

  static String _trimTrailingSlash(String value) {
    if (!value.endsWith('/')) {
      return value;
    }

    return value.substring(0, value.length - 1);
  }
}
