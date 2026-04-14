import '../core/attendance_formatters.dart';
import 'attendance_entry.dart';
import 'player_profile.dart';

class AttendanceDaySummary {
  const AttendanceDaySummary({
    required this.date,
    required this.presentCount,
    required this.absentCount,
    required this.pendingCount,
    required this.totalPlayers,
    this.pendingPlayers = const [],
  });

  final DateTime date;
  final int presentCount;
  final int absentCount;
  final int pendingCount;
  final int totalPlayers;
  final List<PlayerProfile> pendingPlayers;

  int get answeredCount => presentCount + absentCount;

  static List<AttendanceDaySummary> buildForDates(
    List<DateTime> dates,
    List<AttendanceEntry> sourceEntries,
  ) {
    return dates.map((date) {
      var presentCount = 0;
      var absentCount = 0;
      var pendingCount = 0;
      var totalPlayers = 0;
      final pendingPlayers = <PlayerProfile>[];
      final targetDateKey = formatDatabaseAttendanceDate(date);

      for (final entry in sourceEntries) {
        if (formatDatabaseAttendanceDate(entry.attendanceDate) != targetDateKey) {
          continue;
        }

        totalPlayers += 1;

        if (entry.isPresent) {
          presentCount += 1;
        } else if (entry.isAbsent) {
          absentCount += 1;
        } else {
          pendingCount += 1;
          if (entry.player != null) {
            pendingPlayers.add(entry.player!);
          }
        }
      }

      return AttendanceDaySummary(
        date: date,
        presentCount: presentCount,
        absentCount: absentCount,
        pendingCount: pendingCount,
        totalPlayers: totalPlayers,
        pendingPlayers: pendingPlayers,
      );
    }).toList();
  }
}
