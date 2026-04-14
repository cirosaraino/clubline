class AttendanceLineupFilters {
  const AttendanceLineupFilters({
    this.absentPlayerIds = const {},
    this.pendingPlayerIds = const {},
  });

  final Set<dynamic> absentPlayerIds;
  final Set<dynamic> pendingPlayerIds;

  Set<dynamic> get unavailablePlayerIds {
    return {
      ...absentPlayerIds,
      ...pendingPlayerIds,
    };
  }
}
