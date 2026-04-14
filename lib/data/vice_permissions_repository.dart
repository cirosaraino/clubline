import '../models/vice_permissions.dart';
import 'api_client.dart';

class VicePermissionsRepository {
  VicePermissionsRepository({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient.shared;

  final ApiClient _apiClient;

  Future<VicePermissions> fetchPermissions() async {
    try {
      final response = await _apiClient.get('/vice-permissions', authenticated: true);
      final rawPermissions = switch (response) {
        {'permissions': final Map permissions} => Map<String, dynamic>.from(permissions),
        Map permissions => Map<String, dynamic>.from(permissions),
        _ => VicePermissions.defaults.toDatabaseMap(),
      };

      return VicePermissions.fromMap(rawPermissions);
    } on ApiUnauthorizedException {
      return VicePermissions.defaults;
    }
  }

  Future<void> savePermissions(VicePermissions permissions) async {
    await _apiClient.put(
      '/vice-permissions',
      authenticated: true,
      body: permissions.toDatabaseMap(),
    );
  }
}
