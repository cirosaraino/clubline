import '../core/attendance_formatters.dart';

class AttendanceWeek {
  const AttendanceWeek({
    this.id,
    required this.weekStart,
    required this.weekEnd,
    this.selectedDates = const [],
    this.archivedAt,
    this.createdAt,
  });

  final dynamic id;
  final DateTime weekStart;
  final DateTime weekEnd;
  final List<DateTime> selectedDates;
  final DateTime? archivedAt;
  final DateTime? createdAt;

  factory AttendanceWeek.fromMap(Map<String, dynamic> map) {
    final rawSelectedDates = map['selected_dates'];
    final normalizedSelectedDates = <DateTime>[
      if (rawSelectedDates is Iterable)
        ...rawSelectedDates.whereType<Object?>().map(
              (value) => DateTime.parse(value.toString()),
            )
      else if (rawSelectedDates is String && rawSelectedDates.isNotEmpty)
        ...rawSelectedDates
            .replaceAll('{', '')
            .replaceAll('}', '')
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .map(DateTime.parse),
    ];

    return AttendanceWeek(
      id: map['id'],
      weekStart: DateTime.parse(map['week_start'].toString()),
      weekEnd: DateTime.parse(map['week_end'].toString()),
      selectedDates: normalizeAttendanceDates(normalizedSelectedDates),
      archivedAt: map['archived_at'] == null
          ? null
          : DateTime.parse(map['archived_at'].toString()),
      createdAt: map['created_at'] == null
          ? null
          : DateTime.parse(map['created_at'].toString()),
    );
  }

  List<DateTime> get votingDates {
    if (selectedDates.isNotEmpty) return selectedDates;
    return attendanceWeekDates(weekStart, weekEnd);
  }

  String get title => formatAttendanceWeekTitle(weekStart, weekEnd);

  String get subtitle => formatAttendanceWeekSubtitle(weekStart, weekEnd);

  String get selectedDatesSummary => formatAttendanceSelectedDatesSummary(votingDates);

  bool get isArchived => archivedAt != null;
}
