import 'config/app_runtime_config.dart';

class AppBackendConfig {
  const AppBackendConfig._();

  static String get baseUrl => AppRuntimeConfig.instance.apiBaseUrl;
}
