import '../models/lineup.dart';
import '../models/lineup_player_assignment.dart';
import 'api_client.dart';

class LineupRepository {
  LineupRepository({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient.shared;

  final ApiClient _apiClient;

  Future<List<Lineup>> fetchLineups() async {
    final response = await _apiClient.get('/lineups');
    final rawLineups = switch (response) {
      {'lineups': final List lineups} => lineups,
      List lineups => lineups,
      _ => const [],
    };

    return rawLineups
        .map<Lineup>((row) => Lineup.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<Lineup> createLineup(Lineup lineup) async {
    final response = await _apiClient.post(
      '/lineups',
      authenticated: true,
      body: lineup.toDatabaseMap(),
    );

    return _extractLineup(response);
  }

  Future<Lineup> updateLineup(Lineup lineup) async {
    final response = await _apiClient.put(
      '/lineups/${lineup.id}',
      authenticated: true,
      body: lineup.toDatabaseMap(),
    );

    return _extractLineup(response);
  }

  Future<void> deleteLineup(dynamic lineupId) async {
    await _apiClient.delete(
      '/lineups/$lineupId',
      authenticated: true,
    );
  }

  Future<List<LineupPlayerAssignment>> fetchLineupPlayers(dynamic lineupId) async {
    final response = await _apiClient.get('/lineups/$lineupId/players');
    final rawAssignments = switch (response) {
      {'assignments': final List assignments} => assignments,
      List assignments => assignments,
      _ => const [],
    };

    return rawAssignments
        .map<LineupPlayerAssignment>(
          (row) => LineupPlayerAssignment.fromMap(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Future<Map<dynamic, List<LineupPlayerAssignment>>> fetchAssignmentsForLineups(
    List<dynamic> lineupIds,
  ) async {
    if (lineupIds.isEmpty) {
      return const {};
    }

    final response = await _apiClient.get(
      '/lineups/assignments?lineup_ids=${lineupIds.map((id) => Uri.encodeComponent(id.toString())).join(',')}',
    );
    final rawAssignments = switch (response) {
      {'assignments': final List assignments} => assignments,
      List assignments => assignments,
      _ => const [],
    };

    final groupedAssignments = <dynamic, List<LineupPlayerAssignment>>{};

    for (final row in rawAssignments) {
      final assignment = LineupPlayerAssignment.fromMap(
        Map<String, dynamic>.from(row),
      );
      groupedAssignments.putIfAbsent(assignment.lineupId, () => []).add(assignment);
    }

    return groupedAssignments;
  }

  Future<void> replaceLineupPlayers(
    dynamic lineupId,
    List<LineupPlayerAssignment> assignments,
  ) async {
    await _apiClient.put(
      '/lineups/$lineupId/players',
      authenticated: true,
      body: {
        'assignments': assignments.map((assignment) => assignment.toDatabaseMap()).toList(),
      },
    );
  }

  Lineup _extractLineup(dynamic response) {
    final rawLineup = switch (response) {
      {'lineup': final Map lineup} => Map<String, dynamic>.from(lineup),
      Map lineup => Map<String, dynamic>.from(lineup),
      _ => throw const ApiException('Risposta formazione non valida dal backend.'),
    };

    return Lineup.fromMap(rawLineup);
  }
}
