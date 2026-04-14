import 'player_profile.dart';

class LineupPlayerAssignment {
  const LineupPlayerAssignment({
    this.id,
    required this.lineupId,
    required this.playerId,
    required this.positionCode,
    this.player,
  });

  final dynamic id;
  final dynamic lineupId;
  final dynamic playerId;
  final String positionCode;
  final PlayerProfile? player;

  factory LineupPlayerAssignment.fromMap(Map<String, dynamic> map) {
    final playerMap = map['player_profiles'];

    return LineupPlayerAssignment(
      id: map['id'],
      lineupId: map['lineup_id'],
      playerId: map['player_id'],
      positionCode: map['position_code']?.toString() ?? '',
      player: playerMap is Map<String, dynamic>
          ? PlayerProfile.fromMap(playerMap)
          : playerMap is Map
              ? PlayerProfile.fromMap(Map<String, dynamic>.from(playerMap))
              : null,
    );
  }

  Map<String, dynamic> toDatabaseMap() {
    return {
      'lineup_id': lineupId,
      'player_id': playerId,
      'position_code': positionCode,
    };
  }
}
