String formatMatchDateTime(DateTime value) {
  final localValue = value.toLocal();
  final day = localValue.day.toString().padLeft(2, '0');
  final month = localValue.month.toString().padLeft(2, '0');
  final year = localValue.year.toString();
  final hour = localValue.hour.toString().padLeft(2, '0');
  final minute = localValue.minute.toString().padLeft(2, '0');

  return '$day/$month/$year $hour:$minute';
}

String normalizeCompetitionName(String value) {
  return value.trim().toUpperCase();
}

String? normalizeOptionalText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
