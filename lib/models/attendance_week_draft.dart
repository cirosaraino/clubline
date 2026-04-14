class AttendanceWeekDraft {
  const AttendanceWeekDraft({
    required this.referenceDate,
    required this.selectedDates,
  });

  final DateTime referenceDate;
  final List<DateTime> selectedDates;
}
