const String kDefaultTeamName = 'Clubline';

String normalizeTeamName(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? kDefaultTeamName : normalized;
}

String? normalizeOptionalTeamUrl(String? value) {
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

String normalizeTeamLinkLabel(String value) {
  final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  return normalized;
}
