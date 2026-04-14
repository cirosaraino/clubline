const List<String> kAttendanceWeekdayShortLabels = [
  'Lun',
  'Mar',
  'Mer',
  'Gio',
  'Ven',
  'Sab',
  'Dom',
];

const List<String> kAttendanceWeekdayLabels = [
  'Lunedi',
  'Martedi',
  'Mercoledi',
  'Giovedi',
  'Venerdi',
  'Sabato',
  'Domenica',
];

String formatAttendanceDate(DateTime value) {
  final localValue = value.toLocal();
  final day = localValue.day.toString().padLeft(2, '0');
  final month = localValue.month.toString().padLeft(2, '0');
  final year = localValue.year.toString();

  return '$day/$month/$year';
}

String formatAttendanceDayShortLabel(DateTime value) {
  final localValue = value.toLocal();
  return kAttendanceWeekdayShortLabels[localValue.weekday - 1];
}

String formatAttendanceDayLabel(DateTime value) {
  final localValue = value.toLocal();
  return kAttendanceWeekdayLabels[localValue.weekday - 1];
}

String formatAttendanceDayWithDate(DateTime value) {
  final localValue = value.toLocal();
  final day = localValue.day.toString().padLeft(2, '0');
  final month = localValue.month.toString().padLeft(2, '0');

  return '${formatAttendanceDayShortLabel(localValue)} $day/$month';
}

String formatDatabaseAttendanceDate(DateTime value) {
  final localValue = value.toLocal();
  final month = localValue.month.toString().padLeft(2, '0');
  final day = localValue.day.toString().padLeft(2, '0');

  return '${localValue.year}-$month-$day';
}

String formatAttendanceWeekTitle(DateTime weekStart, DateTime weekEnd) {
  final start = weekStart.toLocal();
  final end = weekEnd.toLocal();

  return 'Settimana ${start.day}/${start.month} - ${end.day}/${end.month}';
}

String formatAttendanceWeekSubtitle(DateTime weekStart, DateTime weekEnd) {
  const weekdays = [
    'Lun',
    'Mar',
    'Mer',
    'Gio',
    'Ven',
    'Sab',
    'Dom',
  ];
  const months = [
    'gennaio',
    'febbraio',
    'marzo',
    'aprile',
    'maggio',
    'giugno',
    'luglio',
    'agosto',
    'settembre',
    'ottobre',
    'novembre',
    'dicembre',
  ];

  final start = weekStart.toLocal();
  final end = weekEnd.toLocal();

  return '${weekdays[start.weekday - 1]} ${start.day} ${months[start.month - 1]} - '
      '${weekdays[end.weekday - 1]} ${end.day} ${months[end.month - 1]} ${end.year}';
}

List<DateTime> attendanceWeekDates(DateTime weekStart, DateTime weekEnd) {
  final start = weekStart.toLocal();
  final end = weekEnd.toLocal();
  final dates = <DateTime>[];

  for (var date = DateTime(start.year, start.month, start.day);
      !date.isAfter(DateTime(end.year, end.month, end.day));
      date = date.add(const Duration(days: 1))) {
    dates.add(date);
  }

  return dates;
}

DateTime attendanceCalendarWeekStart(DateTime value) {
  final localValue = value.toLocal();
  return DateTime(
    localValue.year,
    localValue.month,
    localValue.day,
  ).subtract(Duration(days: localValue.weekday - 1));
}

List<DateTime> attendanceCalendarWeekDates(DateTime referenceDate) {
  final start = attendanceCalendarWeekStart(referenceDate);

  return List<DateTime>.generate(
    7,
    (index) => DateTime(start.year, start.month, start.day + index),
  );
}

List<DateTime> normalizeAttendanceDates(Iterable<DateTime> dates) {
  final uniqueDates = <String, DateTime>{};

  for (final date in dates) {
    final normalized = DateTime(date.year, date.month, date.day);
    uniqueDates[formatDatabaseAttendanceDate(normalized)] = normalized;
  }

  final result = uniqueDates.values.toList()
    ..sort((a, b) => a.compareTo(b));

  return result;
}

String formatAttendanceSelectedDatesSummary(List<DateTime> dates) {
  final normalizedDates = normalizeAttendanceDates(dates);
  if (normalizedDates.isEmpty) return 'Nessun giorno selezionato';

  return normalizedDates.map(formatAttendanceDayWithDate).join(' • ');
}

String attendanceAvailabilityLabel(String value) {
  switch (value) {
    case 'yes':
      return 'Presente';
    case 'no':
      return 'Assente';
    case 'pending':
    default:
      return 'In attesa';
  }
}

String attendanceAvailabilityShortLabel(String value) {
  switch (value) {
    case 'yes':
      return 'Si';
    case 'no':
      return 'No';
    case 'pending':
    default:
      return 'Da compilare';
  }
}
