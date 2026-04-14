import '../models/team_info.dart';
import 'api_client.dart';

class TeamInfoRepository {
  TeamInfoRepository({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient.shared;

  final ApiClient _apiClient;

  Future<TeamInfo> fetchTeamInfo() async {
    final response = await _apiClient.get('/team-info');
    final rawTeamInfo = switch (response) {
      {'teamInfo': final Map teamInfo} => Map<String, dynamic>.from(teamInfo),
      Map teamInfo => Map<String, dynamic>.from(teamInfo),
      _ => TeamInfo.defaults.toDatabaseMap(),
    };

    return TeamInfo.fromMap(rawTeamInfo);
  }

  Future<void> saveTeamInfo(TeamInfo teamInfo) async {
    await _apiClient.put(
      '/team-info',
      authenticated: true,
      body: teamInfo.toDatabaseMap(),
    );
  }
}
