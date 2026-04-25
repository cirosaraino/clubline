const List<String> _kLineupWeekdayLabels = [
  'Lunedì',
  'Martedì',
  'Mercoledì',
  'Giovedì',
  'Venerdì',
  'Sabato',
  'Domenica',
];

const List<String> _kLineupMonthLabels = [
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

String formatMatchDateTime(DateTime value) {
  final localValue = value.toLocal();
  final hours = localValue.hour.toString().padLeft(2, '0');
  final minutes = localValue.minute.toString().padLeft(2, '0');

  return '${formatMatchDayLabel(localValue, includeYear: true)} • $hours:$minutes';
}

String formatMatchDayLabel(DateTime value, {bool includeYear = false}) {
  final localValue = value.toLocal();
  final weekday = _kLineupWeekdayLabels[localValue.weekday - 1];
  final month = _kLineupMonthLabels[localValue.month - 1];
  final yearSuffix = includeYear ? ' ${localValue.year}' : '';

  return '$weekday ${localValue.day} $month$yearSuffix';
}

DateTime normalizeMatchCalendarDate(DateTime value) {
  final localValue = value.toLocal();
  return DateTime(localValue.year, localValue.month, localValue.day);
}

DateTime lineupCalendarWeekStart(DateTime value) {
  final localValue = normalizeMatchCalendarDate(value);
  return localValue.subtract(Duration(days: localValue.weekday - 1));
}

DateTime lineupCalendarWeekEnd(DateTime value) {
  return lineupCalendarWeekStart(value).add(const Duration(days: 6));
}

String normalizeCompetitionName(String value) {
  return value.trim().toUpperCase();
}

String? normalizeOptionalText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
