import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/app_backend_config.dart';
import '../../core/app_data_sync.dart';
import '../../core/realtime/app_realtime_bridge.dart';
import '../../data/api_client.dart';
import '../../data/auth_session_store.dart';

class AppRealtimeSyncHost extends StatefulWidget {
  const AppRealtimeSyncHost({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<AppRealtimeSyncHost> createState() => _AppRealtimeSyncHostState();
}

class _AppRealtimeSyncHostState extends State<AppRealtimeSyncHost>
    with WidgetsBindingObserver {
  static const Duration _baseBatchWindow = Duration(milliseconds: 300);
  static const Duration _highTrafficBatchWindow = Duration(milliseconds: 600);
  static const Duration _trafficObservationWindow = Duration(seconds: 1);
  static const Duration _lowTrafficRecoveryWindow = Duration(seconds: 3);
  static const int _highTrafficEventsThreshold = 4;

  StreamSubscription<String>? _messageSubscription;
  Timer? _reconnectTimer;
  Timer? _dispatchTimer;
  int _lastReceivedRevision = 0;
  final AuthSessionStore _sessionStore = AuthSessionStore();
  final ApiClient _apiClient = ApiClient.shared;
  final Set<AppDataScope> _pendingScopes = <AppDataScope>{};
  final List<DateTime> _recentEventTimestamps = <DateTime>[];
  String _lastPendingReason = 'remote_change';
  DateTime? _lastHighTrafficDetectedAt;
  Duration _currentBatchWindow = _baseBatchWindow;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_forceReconnect());
    _reconnectTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (appRealtimeBridge.isConnected) {
        return;
      }
      unawaited(_connectRealtime());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageSubscription?.cancel();
    _reconnectTimer?.cancel();
    _dispatchTimer?.cancel();
    appRealtimeBridge.disconnect();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_forceReconnect());
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      appRealtimeBridge.disconnect();
    }
  }

  Future<void> _forceReconnect() async {
    if (_isConnecting) {
      return;
    }

    _isConnecting = true;
    try {
      appRealtimeBridge.disconnect();
      await _messageSubscription?.cancel();
      _messageSubscription = null;
      await _connectRealtime();
    } finally {
      _isConnecting = false;
    }
  }

  void _scheduleDispatch() {
    if (_dispatchTimer?.isActive == true) {
      return;
    }

    _dispatchTimer = Timer(_currentBatchWindow, () {
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

  void _updateAdaptiveBatchWindow() {
    final now = DateTime.now();

    _recentEventTimestamps.add(now);
    _recentEventTimestamps.removeWhere(
      (eventTime) => now.difference(eventTime) > _trafficObservationWindow,
    );

    final eventsInWindow = _recentEventTimestamps.length;

    if (eventsInWindow >= _highTrafficEventsThreshold) {
      _lastHighTrafficDetectedAt = now;
      _currentBatchWindow = _highTrafficBatchWindow;
      return;
    }

    if (_currentBatchWindow == _highTrafficBatchWindow &&
        _lastHighTrafficDetectedAt != null &&
        now.difference(_lastHighTrafficDetectedAt!) >= _lowTrafficRecoveryWindow) {
      _currentBatchWindow = _baseBatchWindow;
    }
  }

  Future<void> _connectRealtime() async {
    try {
      final session = await _sessionStore.readSession();
      final accessToken = session?.accessToken.trim() ?? '';

      if (accessToken.isEmpty) {
        appRealtimeBridge.disconnect();
        return;
      }

      final realtimeSession = await _apiClient.post(
        '/realtime/session',
        authenticated: true,
        accessToken: accessToken,
      );
      final realtimeSessionMap = Map<String, dynamic>.from(realtimeSession as Map);
      final ticket = realtimeSessionMap['ticket']?.toString().trim() ?? '';
      if (ticket.isEmpty) {
        appRealtimeBridge.disconnect();
        return;
      }

      final baseEventsUri = Uri.parse('${AppBackendConfig.baseUrl}/realtime/events');
      final eventsUri = baseEventsUri.replace(
        queryParameters: {
          'since': '$_lastReceivedRevision',
          'ticket': ticket,
        },
      );

      await appRealtimeBridge.connect(eventsUri.toString());

      _messageSubscription ??= appRealtimeBridge.messages.listen(_handleRawMessage);
    } catch (_) {
      appRealtimeBridge.disconnect();
    }
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
    _updateAdaptiveBatchWindow();
    _pendingScopes.addAll(mappedScopes);
    _lastPendingReason = reason;
    _scheduleDispatch();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
