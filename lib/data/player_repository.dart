import '../core/player_formatters.dart';
import '../models/player_profile.dart';
import 'api_client.dart';

class PlayerRepository {
  PlayerRepository({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient.shared;

  final ApiClient _apiClient;

  Future<List<PlayerProfile>> fetchPlayers() async {
    final response = await _apiClient.get('/players');
    final rawPlayers = switch (response) {
      {'players': final List players} => players,
      List players => players,
      _ => const [],
    };

    final players = rawPlayers
        .map<PlayerProfile>((player) => PlayerProfile.fromMap(Map<String, dynamic>.from(player)))
        .toList();

    players.sort((a, b) {
      final roleComparison = a.primaryRoleSortIndex.compareTo(b.primaryRoleSortIndex);
      if (roleComparison != 0) return roleComparison;

      final surnameComparison = normalizePlayerName(a.cognome).compareTo(
        normalizePlayerName(b.cognome),
      );
      if (surnameComparison != 0) return surnameComparison;

      return normalizePlayerName(a.nome).compareTo(normalizePlayerName(b.nome));
    });

    return players;
  }

  Future<PlayerProfile> createPlayer(PlayerProfile player) async {
    final response = await _apiClient.post(
      '/players',
      authenticated: true,
      body: player.toDatabaseMap(),
    );
    return _extractPlayer(response);
  }

  Future<PlayerProfile> claimPlayer(PlayerProfile player) async {
    final response = await _apiClient.post(
      '/players/claim',
      authenticated: true,
      body: player.toDatabaseMap(),
    );
    return _extractPlayer(response);
  }

  Future<void> updatePlayer(PlayerProfile player) async {
    await _apiClient.put(
      '/players/${player.id}',
      authenticated: true,
      body: player.toDatabaseMap(),
    );
  }

  Future<void> deletePlayer(dynamic playerId) async {
    await _apiClient.delete(
      '/players/$playerId',
      authenticated: true,
    );
  }

  Future<bool> isConsoleIdTaken(
    String consoleId, {
    dynamic excludingPlayerId,
  }) async {
    final existingPlayer = await findPlayerByConsoleId(consoleId);

    if (existingPlayer == null) return false;
    return existingPlayer.id != excludingPlayerId;
  }

  Future<PlayerProfile?> findPlayerByConsoleId(String consoleId) async {
    final normalizedConsoleId = consoleId.trim();
    if (normalizedConsoleId.isEmpty) {
      return null;
    }

    try {
      final response = await _apiClient.get(
        '/players/by-console/${Uri.encodeComponent(normalizedConsoleId)}',
      );
      return _extractPlayer(response);
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  PlayerProfile _extractPlayer(dynamic response) {
    final rawPlayer = switch (response) {
      {'player': final Map player} => Map<String, dynamic>.from(player),
      Map player => Map<String, dynamic>.from(player),
      _ => throw const ApiException('Risposta player non valida dal backend.'),
    };

    return PlayerProfile.fromMap(rawPlayer);
  }
}
