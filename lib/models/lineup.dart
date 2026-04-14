import '../core/lineup_formatters.dart';

class Lineup {
  const Lineup({
    this.id,
    required this.competitionName,
    required this.matchDateTime,
    this.opponentName,
    required this.formationModule,
    this.notes,
    this.createdAt,
  });

  final dynamic id;
  final String competitionName;
  final DateTime matchDateTime;
  final String? opponentName;
  final String formationModule;
  final String? notes;
  final DateTime? createdAt;

  factory Lineup.fromMap(Map<String, dynamic> map) {
    return Lineup(
      id: map['id'],
      competitionName: normalizeCompetitionName(
        map['competition_name']?.toString() ?? '',
      ),
      matchDateTime: DateTime.parse(map['match_datetime'].toString()),
      opponentName: map['opponent_name']?.toString(),
      formationModule: map['formation_module']?.toString() ?? '',
      notes: map['notes']?.toString(),
      createdAt: map['created_at'] == null
          ? null
          : DateTime.parse(map['created_at'].toString()),
    );
  }

  Map<String, dynamic> toDatabaseMap() {
    return {
      'competition_name': normalizeCompetitionName(competitionName),
      'match_datetime': matchDateTime.toUtc().toIso8601String(),
      'opponent_name': normalizeOptionalText(opponentName),
      'formation_module': formationModule,
      'notes': normalizeOptionalText(notes),
    };
  }

  String get matchDateTimeDisplay => formatMatchDateTime(matchDateTime);

  bool get hasOpponentName => opponentName != null && opponentName!.trim().isNotEmpty;
}
