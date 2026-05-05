import 'package:flutter/foundation.dart';

enum AppDataScope {
  clubs,
  players,
  streams,
  lineups,
  attendance,
  clubInfo,
  vicePermissions,
  invites,
  notifications,
}

AppDataScope? parseAppDataScope(String rawScope) {
  switch (rawScope) {
    case 'clubs':
      return AppDataScope.clubs;
    case 'players':
      return AppDataScope.players;
    case 'streams':
      return AppDataScope.streams;
    case 'lineups':
      return AppDataScope.lineups;
    case 'attendance':
      return AppDataScope.attendance;
    case 'clubInfo':
    case 'teamInfo':
      return AppDataScope.clubInfo;
    case 'vicePermissions':
      return AppDataScope.vicePermissions;
    case 'invites':
      return AppDataScope.invites;
    case 'notifications':
      return AppDataScope.notifications;
    default:
      return null;
  }
}

class AppDataChange {
  const AppDataChange({
    required this.revision,
    required this.scopes,
    this.reason = '',
  });

  final int revision;
  final Set<AppDataScope> scopes;
  final String reason;

  bool affects(Set<AppDataScope> watchedScopes) {
    for (final scope in scopes) {
      if (watchedScopes.contains(scope)) return true;
    }

    return false;
  }
}

class AppDataSync extends ChangeNotifier {
  AppDataSync._();

  static final AppDataSync instance = AppDataSync._();

  int _revision = 0;
  AppDataChange? _latestChange;

  AppDataChange? get latestChange => _latestChange;

  void notifyDataChanged(Set<AppDataScope> scopes, {String reason = ''}) {
    _revision += 1;
    _latestChange = AppDataChange(
      revision: _revision,
      scopes: scopes,
      reason: reason,
    );
    notifyListeners();
  }
}
