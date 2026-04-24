import '../core/attendance_formatters.dart';
import 'attendance_entry.dart';
import 'player_profile.dart';

class AttendancePlayerEntries {
  AttendancePlayerEntries({
    required this.playerId,
    required this.player,
    required this.entries,
  }) : _entriesByDate = {
         for (final entry in entries)
           formatDatabaseAttendanceDate(entry.attendanceDate): entry,
       };

  final dynamic playerId;
  final PlayerProfile? player;
  final List<AttendanceEntry> entries;
  final Map<String, AttendanceEntry> _entriesByDate;

  AttendanceEntry? entryForDate(DateTime date) {
    return _entriesByDate[formatDatabaseAttendanceDate(date)];
  }

  int completedDaysCount(Iterable<DateTime> dates) {
    return dates
        .where((date) => !(entryForDate(date)?.isPending ?? true))
        .length;
  }

  static List<AttendancePlayerEntries> groupEntries(
    List<AttendanceEntry> sourceEntries,
  ) {
    final grouped = <dynamic, List<AttendanceEntry>>{};
    final playersById = <dynamic, PlayerProfile?>{};

    for (final entry in sourceEntries) {
      final playerEntries = grouped.putIfAbsent(entry.playerId, () => []);
      final existingIndex = playerEntries.indexWhere(
        (candidate) =>
            formatDatabaseAttendanceDate(candidate.attendanceDate) ==
            formatDatabaseAttendanceDate(entry.attendanceDate),
      );

      if (existingIndex >= 0) {
        final existing = playerEntries[existingIndex];
        final shouldReplace =
            (entry.isResolved && !existing.isResolved) ||
            (entry.isResolved == existing.isResolved &&
                entry.recencyScore >= existing.recencyScore);
        if (shouldReplace) {
          playerEntries[existingIndex] = entry;
        }
      } else {
        playerEntries.add(entry);
      }

      playersById[entry.playerId] = entry.player;
    }

    return grouped.entries.map((group) {
      final sortedEntries = [...group.value]
        ..sort((a, b) => a.attendanceDate.compareTo(b.attendanceDate));

      return AttendancePlayerEntries(
        playerId: group.key,
        player: playersById[group.key],
        entries: sortedEntries,
      );
    }).toList();
  }
}
