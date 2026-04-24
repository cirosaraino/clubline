import '../core/attendance_formatters.dart';
import 'player_profile.dart';

class AttendanceEntry {
  const AttendanceEntry({
    this.id,
    required this.weekId,
    required this.playerId,
    required this.attendanceDate,
    required this.availability,
    this.updatedByPlayerId,
    this.updatedAt,
    this.createdAt,
    this.player,
  });

  final dynamic id;
  final dynamic weekId;
  final dynamic playerId;
  final DateTime attendanceDate;
  final String availability;
  final dynamic updatedByPlayerId;
  final DateTime? updatedAt;
  final DateTime? createdAt;
  final PlayerProfile? player;

  factory AttendanceEntry.fromMap(Map<String, dynamic> map) {
    final playerMap = map['player'] ?? map['player_profiles'];

    return AttendanceEntry(
      id: map['id'],
      weekId: map['week_id'],
      playerId: map['player_id'],
      attendanceDate: DateTime.parse(map['attendance_date'].toString()),
      availability: map['availability']?.toString() ?? 'pending',
      updatedByPlayerId: map['updated_by_player_id'],
      updatedAt: map['updated_at'] == null
          ? null
          : DateTime.parse(map['updated_at'].toString()),
      createdAt: map['created_at'] == null
          ? null
          : DateTime.parse(map['created_at'].toString()),
      player: playerMap is Map<String, dynamic>
          ? PlayerProfile.fromMap(playerMap)
          : playerMap is Map
          ? PlayerProfile.fromMap(Map<String, dynamic>.from(playerMap))
          : null,
    );
  }

  String get availabilityLabel => attendanceAvailabilityLabel(availability);

  String get availabilityShortLabel =>
      attendanceAvailabilityShortLabel(availability);

  String get attendanceDateLabel => formatAttendanceDate(attendanceDate);

  String get attendanceDayLabel => formatAttendanceDayLabel(attendanceDate);

  String get attendanceDayShortLabel =>
      formatAttendanceDayShortLabel(attendanceDate);

  String get attendanceDayWithDateLabel =>
      formatAttendanceDayWithDate(attendanceDate);

  String get entryKey =>
      '${playerId}_${formatDatabaseAttendanceDate(attendanceDate)}';

  bool get isPending => availability == 'pending';

  bool get isPresent => availability == 'yes';

  bool get isAbsent => availability == 'no';

  bool get isResolved => availability != 'pending';

  int get recencyScore {
    final updated = updatedAt?.millisecondsSinceEpoch ?? 0;
    if (updated != 0) {
      return updated;
    }

    return createdAt?.millisecondsSinceEpoch ?? 0;
  }

  AttendanceEntry copyWith({
    dynamic id,
    dynamic weekId,
    dynamic playerId,
    DateTime? attendanceDate,
    String? availability,
    dynamic updatedByPlayerId,
    DateTime? updatedAt,
    DateTime? createdAt,
    PlayerProfile? player,
  }) {
    return AttendanceEntry(
      id: id ?? this.id,
      weekId: weekId ?? this.weekId,
      playerId: playerId ?? this.playerId,
      attendanceDate: attendanceDate ?? this.attendanceDate,
      availability: availability ?? this.availability,
      updatedByPlayerId: updatedByPlayerId ?? this.updatedByPlayerId,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      player: player ?? this.player,
    );
  }
}
