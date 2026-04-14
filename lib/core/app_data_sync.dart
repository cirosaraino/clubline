import 'package:flutter/foundation.dart';

enum AppDataScope {
  players,
  streams,
  lineups,
  attendance,
  teamInfo,
  vicePermissions,
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

  void notifyDataChanged(
    Set<AppDataScope> scopes, {
    String reason = '',
  }) {
    _revision += 1;
    _latestChange = AppDataChange(
      revision: _revision,
      scopes: scopes,
      reason: reason,
    );
    notifyListeners();
  }
}
