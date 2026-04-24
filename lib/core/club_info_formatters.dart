const String kDefaultClubName = 'Clubline';

String normalizeClubName(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? kDefaultClubName : normalized;
}

String? normalizeOptionalClubUrl(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return null;
  }

  final withScheme = trimmed.contains('://') ? trimmed : 'https://$trimmed';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  if (!uri.hasAuthority || uri.host.trim().isEmpty) {
    return null;
  }

  return uri.toString();
}

String normalizeClubLinkLabel(String value) {
  final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  return normalized;
}

@Deprecated('Use kDefaultClubName instead.')
const String kDefaultTeamName = kDefaultClubName;

@Deprecated('Use normalizeClubName instead.')
String normalizeTeamName(String value) => normalizeClubName(value);

@Deprecated('Use normalizeOptionalClubUrl instead.')
String? normalizeOptionalTeamUrl(String? value) =>
    normalizeOptionalClubUrl(value);

@Deprecated('Use normalizeClubLinkLabel instead.')
String normalizeTeamLinkLabel(String value) => normalizeClubLinkLabel(value);
