import '../core/attendance_formatters.dart';
import '../models/attendance_entry.dart';
import '../models/attendance_lineup_filters.dart';
import '../models/attendance_week.dart';
import 'api_client.dart';

class AttendanceRepository {
  AttendanceRepository({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient.shared;

  final ApiClient _apiClient;

  Future<AttendanceWeek?> fetchActiveWeek() async {
    final response = await _apiClient.get(
      '/attendance/active-week',
      authenticated: true,
    );

    final rawWeek = switch (response) {
      {'week': final Map week} => Map<String, dynamic>.from(week),
      {'week': null} => null,
      Map week => Map<String, dynamic>.from(week),
      _ => null,
    };

    if (rawWeek == null) {
      return null;
    }

    return AttendanceWeek.fromMap(rawWeek);
  }

  Future<AttendanceWeek?> createWeek({
    required DateTime referenceDate,
    required List<DateTime> selectedDates,
  }) async {
    final normalizedDates = normalizeAttendanceDates(selectedDates);

    final response = await _apiClient.post(
      '/attendance/weeks',
      authenticated: true,
      body: {
        'reference_date': formatDatabaseAttendanceDate(referenceDate),
        'selected_dates': normalizedDates.map(formatDatabaseAttendanceDate).toList(),
      },
    );

    final rawWeek = switch (response) {
      {'week': final Map week} => Map<String, dynamic>.from(week),
      {'week': null} => null,
      Map week => Map<String, dynamic>.from(week),
      _ => null,
    };

    if (rawWeek == null) {
      return null;
    }

    return AttendanceWeek.fromMap(rawWeek);
  }

  Future<void> syncWeekEntries(dynamic weekId) async {
    await _apiClient.post(
      '/attendance/weeks/$weekId/sync',
      authenticated: true,
    );
  }

  Future<void> archiveWeek(dynamic weekId) async {
    await _apiClient.post(
      '/attendance/weeks/$weekId/archive',
      authenticated: true,
    );
  }

  Future<void> restoreArchivedWeek(dynamic weekId) async {
    await _apiClient.post(
      '/attendance/weeks/$weekId/restore',
      authenticated: true,
    );
  }

  Future<void> deleteArchivedWeek(dynamic weekId) async {
    await _apiClient.delete(
      '/attendance/weeks/$weekId',
      authenticated: true,
    );
  }

  Future<List<AttendanceEntry>> fetchEntriesForWeek(dynamic weekId) async {
    final response = await _apiClient.get(
      '/attendance/weeks/$weekId/entries',
      authenticated: true,
    );
    final rawEntries = switch (response) {
      {'entries': final List entries} => entries,
      List entries => entries,
      _ => const [],
    };

    return rawEntries
        .map<AttendanceEntry>(
          (entry) => AttendanceEntry.fromMap(Map<String, dynamic>.from(entry)),
        )
        .toList();
  }

  Future<void> saveAvailability({
    required dynamic weekId,
    required dynamic playerId,
    required DateTime attendanceDate,
    required String availability,
    required dynamic updatedByPlayerId,
  }) async {
    await _apiClient.put(
      '/attendance/entries',
      authenticated: true,
      body: {
        'week_id': weekId,
        'player_id': playerId,
        'attendance_date': formatDatabaseAttendanceDate(attendanceDate),
        'availability': availability,
        'updated_by_player_id': updatedByPlayerId,
      },
    );
  }

  Future<List<AttendanceWeek>> fetchArchivedWeeks({
    dynamic excludingWeekId,
    int limit = 12,
  }) async {
    final queryParameters = <String>[
      if (excludingWeekId != null) 'excluding_week_id=${Uri.encodeComponent(excludingWeekId.toString())}',
      'limit=$limit',
    ];

    final response = await _apiClient.get(
      '/attendance/archived-weeks?${queryParameters.join('&')}',
      authenticated: true,
    );
    final rawWeeks = switch (response) {
      {'weeks': final List weeks} => weeks,
      List weeks => weeks,
      _ => const [],
    };

    return rawWeeks
        .map<AttendanceWeek>(
          (week) => AttendanceWeek.fromMap(Map<String, dynamic>.from(week)),
        )
        .toList();
  }

  Future<Set<dynamic>> fetchAbsentPlayerIdsForDate(DateTime targetDate) async {
    final filters = await fetchLineupFiltersForDate(targetDate);
    return filters.absentPlayerIds;
  }

  Future<AttendanceLineupFilters> fetchLineupFiltersForDate(DateTime targetDate) async {
    final normalizedDate = formatDatabaseAttendanceDate(targetDate);
    final response = await _apiClient.get(
      '/attendance/lineup-filters?date=${Uri.encodeComponent(normalizedDate)}',
      authenticated: true,
    );

    final rawFilters = switch (response) {
      {'filters': final Map filters} => Map<String, dynamic>.from(filters),
      Map filters => Map<String, dynamic>.from(filters),
      _ => const <String, dynamic>{},
    };

    final rawAbsent = rawFilters['absentPlayerIds'];
    final rawPending = rawFilters['pendingPlayerIds'];

    return AttendanceLineupFilters(
      absentPlayerIds: rawAbsent is Iterable ? rawAbsent.toSet() : const {},
      pendingPlayerIds: rawPending is Iterable ? rawPending.toSet() : const {},
    );
  }
}
