import '../models/club_info.dart';
import 'api_client.dart';

class ClubInfoRepository {
  ClubInfoRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.shared;

  final ApiClient _apiClient;

  Future<ClubInfo> fetchClubInfo() async {
    final response = await _apiClient.get('/club-info', authenticated: true);
    final rawClubInfo = switch (response) {
      {'clubInfo': final Map clubInfo} => Map<String, dynamic>.from(clubInfo),
      {'teamInfo': final Map clubInfo} => Map<String, dynamic>.from(clubInfo),
      Map clubInfo => Map<String, dynamic>.from(clubInfo),
      _ => ClubInfo.defaults.toDatabaseMap(),
    };

    return ClubInfo.fromMap(rawClubInfo);
  }

  Future<void> saveClubInfo(
    ClubInfo clubInfo, {
    String? logoDataUrl,
  }) async {
    await _apiClient.put(
      '/club-info',
      authenticated: true,
      body: {
        ...clubInfo.toDatabaseMap(),
        if (logoDataUrl != null && logoDataUrl.trim().isNotEmpty)
          'logo_data_url': logoDataUrl.trim(),
      },
    );
  }
}

@Deprecated('Use ClubInfoRepository instead.')
class TeamInfoRepository extends ClubInfoRepository {
  TeamInfoRepository({super.apiClient});
}
