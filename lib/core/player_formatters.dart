import 'player_constants.dart';

String normalizePlayerName(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;

  final normalized = trimmed.toLowerCase();
  final buffer = StringBuffer();
  var shouldUppercase = true;

  for (final char in normalized.split('')) {
    if (RegExp(r'[a-z]').hasMatch(char) && shouldUppercase) {
      buffer.write(char.toUpperCase());
      shouldUppercase = false;
      continue;
    }

    buffer.write(char);
    shouldUppercase = char == ' ' || char == '\'' || char == '-';
  }

  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
}

String? normalizePlayerAccountEmail(String? value) {
  final trimmed = value?.trim().toLowerCase();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

String? roleCategoryLabel(String? role) {
  if (role == null || role.isEmpty || role == '-') return null;
  return kRoleCategories[role];
}

List<String> normalizeRoleCodes(Iterable<String?> values) {
  final normalizedRoles = <String>[];

  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) continue;
    if (!kPlayerRoles.contains(trimmed)) continue;
    if (normalizedRoles.contains(trimmed)) continue;
    normalizedRoles.add(trimmed);
  }

  return normalizedRoles;
}

String shirtNumberLabel(int? shirtNumber) {
  if (shirtNumber == null) return '-';
  return shirtNumber == 0 ? '00' : '$shirtNumber';
}

String normalizeTeamRole(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return 'player';
  return kTeamRoles.contains(normalized) ? normalized : 'player';
}

String teamRoleLabel(String? value) {
  final normalized = normalizeTeamRole(value);
  return kTeamRoleLabels[normalized] ?? kTeamRoleLabels['player']!;
}
