String formatPlayedOnDate(DateTime value) {
  final localValue = value.toLocal();
  final day = localValue.day.toString().padLeft(2, '0');
  final month = localValue.month.toString().padLeft(2, '0');
  final year = localValue.year.toString();

  return '$day/$month/$year';
}

String formatPlayedOnSectionLabel(DateTime value) {
  const weekdays = [
    'Lunedi',
    'Martedi',
    'Mercoledi',
    'Giovedi',
    'Venerdi',
    'Sabato',
    'Domenica',
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

  final localValue = value.toLocal();
  final weekday = weekdays[localValue.weekday - 1];
  final month = months[localValue.month - 1];

  return '$weekday ${localValue.day} $month ${localValue.year}';
}

String formatStreamDateTime(DateTime value) {
  final localValue = value.toLocal();
  final day = localValue.day.toString().padLeft(2, '0');
  final month = localValue.month.toString().padLeft(2, '0');
  final year = localValue.year.toString();
  final hour = localValue.hour.toString().padLeft(2, '0');
  final minute = localValue.minute.toString().padLeft(2, '0');

  return '$day/$month/$year $hour:$minute';
}

DateTime normalizePlayedOnDate(DateTime value) {
  final localValue = value.toLocal();
  return DateTime(localValue.year, localValue.month, localValue.day);
}

String? normalizeOptionalResult(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

String? normalizeOptionalCompetitionName(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed.toUpperCase();
}

String normalizeStreamTitle(String value) {
  return value.trim();
}

String normalizeStreamUrl(String value) {
  return value.trim();
}

bool isValidStreamUrl(String value) {
  final normalizedValue = normalizeStreamUrl(value);
  if (normalizedValue.isEmpty) return false;

  final uri = Uri.tryParse(normalizedValue);
  if (uri == null) return false;

  return (uri.scheme == 'http' || uri.scheme == 'https') &&
      (uri.host.isNotEmpty || uri.hasAuthority);
}

String streamStatusLabel(String status) {
  switch (status) {
    case 'live':
      return 'LIVE';
    case 'ended':
      return 'CONCLUSA';
    default:
      return status.toUpperCase();
  }
}
