import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/app_backend_config.dart';
import '../../core/app_data_sync.dart';
import '../../core/realtime/app_realtime_bridge.dart';

class AppRealtimeSyncHost extends StatefulWidget {
  const AppRealtimeSyncHost({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<AppRealtimeSyncHost> createState() => _AppRealtimeSyncHostState();
}

class _AppRealtimeSyncHostState extends State<AppRealtimeSyncHost> {
  static const Duration _batchWindow = Duration(milliseconds: 300);

  StreamSubscription<String>? _messageSubscription;
  Timer? _reconnectTimer;
  Timer? _dispatchTimer;
  int _lastReceivedRevision = 0;
  final Set<AppDataScope> _pendingScopes = <AppDataScope>{};
  String _lastPendingReason = 'remote_change';

  @override
  void initState() {
    super.initState();
    _connectRealtime();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (appRealtimeBridge.isConnected) {
        return;
      }
      _connectRealtime();
    });
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _reconnectTimer?.cancel();
    _dispatchTimer?.cancel();
    appRealtimeBridge.disconnect();
    super.dispose();
  }

  void _scheduleDispatch() {
    if (_dispatchTimer?.isActive == true) {
      return;
    }

    _dispatchTimer = Timer(_batchWindow, () {
      if (_pendingScopes.isEmpty) {
        return;
      }

      final batchedScopes = Set<AppDataScope>.from(_pendingScopes);
      final batchedReason = _lastPendingReason;

      _pendingScopes.clear();

      AppDataSync.instance.notifyDataChanged(
        batchedScopes,
        reason: 'remote_$batchedReason',
      );
    });
  }

  String _eventsUrl() {
    final baseUrl = AppBackendConfig.baseUrl;
    return '$baseUrl/realtime/events?since=$_lastReceivedRevision';
  }

  Future<void> _connectRealtime() async {
    await appRealtimeBridge.connect(_eventsUrl());

    _messageSubscription ??= appRealtimeBridge.messages.listen(_handleRawMessage);
  }

  AppDataScope? _mapScope(String rawScope) {
    switch (rawScope) {
      case 'players':
        return AppDataScope.players;
      case 'streams':
        return AppDataScope.streams;
      case 'lineups':
        return AppDataScope.lineups;
      case 'attendance':
        return AppDataScope.attendance;
      case 'teamInfo':
        return AppDataScope.teamInfo;
      case 'vicePermissions':
        return AppDataScope.vicePermissions;
      default:
        return null;
    }
  }

  void _handleRawMessage(String payload) {
    dynamic decoded;
    try {
      decoded = jsonDecode(payload);
    } catch (_) {
      return;
    }

    if (decoded is! Map) {
      return;
    }

    final rawRevision = decoded['revision'];
    final revision = rawRevision is int
        ? rawRevision
        : int.tryParse(rawRevision?.toString() ?? '');

    if (revision == null || revision <= _lastReceivedRevision) {
      return;
    }

    _lastReceivedRevision = revision;

    final rawScopes = decoded['scopes'];
    if (rawScopes is! List) {
      return;
    }

    final mappedScopes = <AppDataScope>{};
    for (final rawScope in rawScopes) {
      final scope = _mapScope(rawScope.toString());
      if (scope != null) {
        mappedScopes.add(scope);
      }
    }

    if (mappedScopes.isEmpty) {
      return;
    }

    final reason = decoded['reason']?.toString() ?? 'remote_change';
    _pendingScopes.addAll(mappedScopes);
    _lastPendingReason = reason;
    _scheduleDispatch();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
