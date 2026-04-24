import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase/supabase.dart';

import '../../core/app_backend_config.dart';
import '../../core/app_data_sync.dart';
import '../../core/app_session.dart';
import '../../core/app_supabase_config.dart';
import '../../core/config/app_runtime_config.dart';
import '../../core/realtime/app_realtime_bridge.dart';
import '../../data/api_client.dart';
import '../../data/auth_session_store.dart';
import '../../models/auth_session.dart';

class AppRealtimeSyncHost extends StatefulWidget {
  const AppRealtimeSyncHost({super.key, required this.child});

  final Widget child;

  @override
  State<AppRealtimeSyncHost> createState() => _AppRealtimeSyncHostState();
}

enum _RealtimeTransportMode { supabase, local }

enum _RealtimeChannelHealth { pending, healthy, unhealthy }

class _RealtimeScopeSnapshot {
  const _RealtimeScopeSnapshot({
    required this.userId,
    required this.userEmail,
    required this.clubId,
    required this.playerId,
    required this.isCaptain,
    required this.canManageAttendanceAll,
  });

  factory _RealtimeScopeSnapshot.fromState({
    required AuthSession session,
    required AppSessionController? controller,
  }) {
    return _RealtimeScopeSnapshot(
      userId: session.user.id.trim(),
      userEmail: session.user.email.trim().toLowerCase(),
      clubId: _normalizeEntityId(controller?.currentClub?.id),
      playerId: _normalizeEntityId(controller?.currentUser?.id),
      isCaptain: controller?.membership?.isCaptain == true,
      canManageAttendanceAll:
          controller?.currentUser?.canManageAttendanceAll == true,
    );
  }

  final String userId;
  final String userEmail;
  final String? clubId;
  final String? playerId;
  final bool isCaptain;
  final bool canManageAttendanceAll;

  String get signature {
    return [
      userId,
      userEmail,
      clubId ?? '-',
      playerId ?? '-',
      isCaptain ? 'captain' : 'member',
      canManageAttendanceAll ? 'attendance-all' : 'attendance-self',
    ].join('|');
  }
}

class _RealtimeChannelPlan {
  const _RealtimeChannelPlan({required this.name, required this.bindings});

  final String name;
  final List<_RealtimeBindingPlan> bindings;
}

class _RealtimeBindingPlan {
  const _RealtimeBindingPlan({
    required this.table,
    required this.scopes,
    required this.reason,
    this.filter,
  });

  final String table;
  final Set<AppDataScope> scopes;
  final String reason;
  final PostgresChangeFilter? filter;
}

class _AppRealtimeSyncHostState extends State<AppRealtimeSyncHost>
    with WidgetsBindingObserver {
  static const Duration _baseBatchWindow = Duration(milliseconds: 300);
  static const Duration _highTrafficBatchWindow = Duration(milliseconds: 600);
  static const Duration _trafficObservationWindow = Duration(seconds: 1);
  static const Duration _lowTrafficRecoveryWindow = Duration(seconds: 3);
  static const Duration _reconnectPollInterval = Duration(seconds: 6);
  static const Duration _sessionRebindDelay = Duration(milliseconds: 250);
  static const int _highTrafficEventsThreshold = 4;
  final AuthSessionStore _sessionStore = AuthSessionStore();
  final ApiClient _apiClient = ApiClient.shared;
  final AppSupabaseConfigRepository _supabaseConfigRepository =
      AppSupabaseConfigRepository.instance;
  final Set<AppDataScope> _pendingScopes = <AppDataScope>{};
  final List<DateTime> _recentEventTimestamps = <DateTime>[];
  final Map<String, RealtimeChannel> _supabaseChannelsByName =
      <String, RealtimeChannel>{};
  final Map<String, _RealtimeChannelPlan> _supabaseChannelPlansByName =
      <String, _RealtimeChannelPlan>{};
  final Map<String, _RealtimeChannelHealth> _supabaseChannelHealthByName =
      <String, _RealtimeChannelHealth>{};
  final Set<String> _reconnectingSupabaseChannelNames = <String>{};

  AppSessionController? _sessionController;
  StreamSubscription<String>? _localMessageSubscription;
  SupabaseClient? _supabaseClient;
  Timer? _reconnectTimer;
  Timer? _dispatchTimer;
  Timer? _sessionRebindTimer;
  String _lastPendingReason = 'remote_change';
  DateTime? _lastHighTrafficDetectedAt;
  Duration _currentBatchWindow = _baseBatchWindow;
  String? _lastScopeSignature;
  String? _lastAccessToken;
  String? _supabaseUrl;
  String? _supabaseAnonKey;
  _RealtimeTransportMode? _activeTransport;
  bool _transportConnected = false;
  bool _isConnecting = false;
  bool _syncQueued = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reconnectTimer = Timer.periodic(_reconnectPollInterval, (_) {
      _pollRealtimeHealth();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppSessionScope.read(context);
    if (!identical(_sessionController, controller)) {
      _sessionController?.removeListener(_handleSessionControllerChanged);
      _sessionController = controller;
      controller.addListener(_handleSessionControllerChanged);
      unawaited(_syncRealtimeBinding(force: true));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _sessionController?.removeListener(_handleSessionControllerChanged);
    _reconnectTimer?.cancel();
    _dispatchTimer?.cancel();
    _sessionRebindTimer?.cancel();
    unawaited(_disconnectRealtime(disposeClient: true));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncRealtimeBinding(force: true));
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      unawaited(_disconnectRealtime());
    }
  }

  void _handleSessionControllerChanged() {
    _sessionRebindTimer?.cancel();
    _sessionRebindTimer = Timer(_sessionRebindDelay, () {
      unawaited(_syncRealtimeBinding());
    });
  }

  Future<void> _syncRealtimeBinding({bool force = false}) async {
    if (_disposed) {
      return;
    }

    if (_isConnecting) {
      _syncQueued = true;
      return;
    }

    _isConnecting = true;
    try {
      final session = await _sessionStore.readSession();
      final accessToken = session?.accessToken.trim() ?? '';
      if (session == null || accessToken.isEmpty || session.user.id.isEmpty) {
        _lastScopeSignature = null;
        _lastAccessToken = null;
        await _disconnectRealtime();
        return;
      }

      final snapshot = _RealtimeScopeSnapshot.fromState(
        session: session,
        controller: _sessionController,
      );
      final config = await _supabaseConfigRepository.load();
      final transport = _resolveTransportMode(config);
      final scopeSignature = '${transport.name}|${snapshot.signature}';
      final tokenChanged = _lastAccessToken != accessToken;
      final shouldReconnect =
          force ||
          !_transportConnected ||
          _activeTransport != transport ||
          _lastScopeSignature != scopeSignature ||
          tokenChanged;

      if (!shouldReconnect) {
        return;
      }

      switch (transport) {
        case _RealtimeTransportMode.supabase:
          await _connectSupabaseRealtime(
            config: config,
            snapshot: snapshot,
            accessToken: accessToken,
          );
          break;
        case _RealtimeTransportMode.local:
          await _connectLocalRealtime(accessToken: accessToken);
          break;
      }

      _activeTransport = transport;
      _lastScopeSignature = scopeSignature;
      _lastAccessToken = accessToken;
    } catch (error, stackTrace) {
      debugPrint('Realtime binding failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _transportConnected = false;
    } finally {
      _isConnecting = false;
      if (_syncQueued && !_disposed) {
        _syncQueued = false;
        unawaited(_syncRealtimeBinding(force: true));
      }
    }
  }

  _RealtimeTransportMode _resolveTransportMode(AppSupabaseConfig config) {
    final requested = AppRuntimeConfig.instance.realtimeTransport;
    if (requested == 'local' && config.localRealtimeFallbackEnabled) {
      return _RealtimeTransportMode.local;
    }
    return _RealtimeTransportMode.supabase;
  }

  Future<void> _connectLocalRealtime({required String accessToken}) async {
    await _disconnectSupabaseChannels();

    await _localMessageSubscription?.cancel();
    _localMessageSubscription = null;
    appRealtimeBridge.disconnect();
    _transportConnected = false;

    final realtimeSession = await _apiClient.post(
      '/realtime/session',
      authenticated: true,
      accessToken: accessToken,
    );
    final realtimeSessionMap = Map<String, dynamic>.from(
      realtimeSession as Map,
    );
    final ticket = realtimeSessionMap['ticket']?.toString().trim() ?? '';
    if (ticket.isEmpty) {
      throw const ApiException('Ticket realtime locale non disponibile.');
    }

    final baseEventsUri = Uri.parse(
      '${AppBackendConfig.baseUrl}/realtime/events',
    );
    final eventsUri = baseEventsUri.replace(
      queryParameters: {'since': '0', 'ticket': ticket},
    );

    await appRealtimeBridge.connect(eventsUri.toString());
    _localMessageSubscription = appRealtimeBridge.messages.listen(
      _handleRawLocalMessage,
    );
    _transportConnected = true;
  }

  Future<void> _connectSupabaseRealtime({
    required AppSupabaseConfig config,
    required _RealtimeScopeSnapshot snapshot,
    required String accessToken,
  }) async {
    await _disconnectLocalRealtime();
    await _ensureSupabaseClient(config);
    _transportConnected = false;

    final client = _supabaseClient;
    if (client == null) {
      throw const ApiException('Client Supabase realtime non inizializzato.');
    }

    await client.realtime.setAuth(accessToken);
    await _disconnectSupabaseChannels();

    final plans = _buildSupabaseChannelPlans(snapshot);
    _supabaseChannelPlansByName
      ..clear()
      ..addEntries(plans.map((plan) => MapEntry(plan.name, plan)));
    for (final plan in plans) {
      _subscribeSupabaseChannel(client, plan);
    }
    _updateSupabaseTransportHealth();
  }

  Future<void> _ensureSupabaseClient(AppSupabaseConfig config) async {
    final currentClient = _supabaseClient;
    if (currentClient != null &&
        _supabaseUrl == config.url &&
        _supabaseAnonKey == config.anonKey) {
      return;
    }

    await _disposeSupabaseClient();

    _supabaseClient = SupabaseClient(
      config.url,
      config.anonKey,
      accessToken: () async {
        final session = await _sessionStore.readSession();
        final token = session?.accessToken.trim() ?? '';
        return token.isEmpty ? null : token;
      },
    );
    _supabaseUrl = config.url;
    _supabaseAnonKey = config.anonKey;
  }

  List<_RealtimeChannelPlan> _buildSupabaseChannelPlans(
    _RealtimeScopeSnapshot snapshot,
  ) {
    final userBindings = <_RealtimeBindingPlan>[
      _binding(
        table: 'memberships',
        filter: _eqFilter('auth_user_id', snapshot.userId),
        scopes: {AppDataScope.clubs, AppDataScope.players},
        reason: 'membership',
      ),
      _binding(
        table: 'join_requests',
        filter: _eqFilter('requester_user_id', snapshot.userId),
        scopes: {AppDataScope.clubs},
        reason: 'join_request',
      ),
      _binding(
        table: 'leave_requests',
        filter: _eqFilter('requested_by_user_id', snapshot.userId),
        scopes: {AppDataScope.clubs},
        reason: 'leave_request',
      ),
      _binding(
        table: 'player_profiles',
        filter: _eqFilter('auth_user_id', snapshot.userId),
        scopes: {
          AppDataScope.players,
          AppDataScope.attendance,
          AppDataScope.lineups,
        },
        reason: 'player_profile',
      ),
      if (snapshot.userEmail.isNotEmpty)
        _binding(
          table: 'player_profiles',
          filter: _eqFilter('account_email', snapshot.userEmail),
          scopes: {
            AppDataScope.players,
            AppDataScope.attendance,
            AppDataScope.lineups,
          },
          reason: 'player_profile',
        ),
    ];

    final plans = <_RealtimeChannelPlan>[
      _RealtimeChannelPlan(
        name: 'clubline:user:${snapshot.userId}',
        bindings: userBindings,
      ),
    ];

    final clubId = snapshot.clubId;
    if (clubId == null || clubId.isEmpty) {
      return plans;
    }

    plans.add(
      _RealtimeChannelPlan(
        name: 'clubline:club:$clubId',
        bindings: <_RealtimeBindingPlan>[
          _binding(
            table: 'clubs',
            filter: _eqFilter('id', clubId),
            scopes: {AppDataScope.clubs, AppDataScope.teamInfo},
            reason: 'club',
          ),
          _binding(
            table: 'club_settings',
            filter: _eqFilter('club_id', clubId),
            scopes: {AppDataScope.teamInfo},
            reason: 'club_settings',
          ),
          _binding(
            table: 'club_permission_settings',
            filter: _eqFilter('club_id', clubId),
            scopes: {AppDataScope.vicePermissions, AppDataScope.players},
            reason: 'club_permission_settings',
          ),
          _binding(
            table: 'memberships',
            filter: _eqFilter('club_id', clubId),
            scopes: {AppDataScope.clubs, AppDataScope.players},
            reason: 'membership',
          ),
          _binding(
            table: 'player_profiles',
            filter: _eqFilter('club_id', clubId),
            scopes: {
              AppDataScope.players,
              AppDataScope.attendance,
              AppDataScope.lineups,
            },
            reason: 'player_profile',
          ),
          _binding(
            table: 'stream_links',
            filter: _eqFilter('club_id', clubId),
            scopes: {AppDataScope.streams},
            reason: 'stream',
          ),
          _binding(
            table: 'lineups',
            filter: _eqFilter('club_id', clubId),
            scopes: {AppDataScope.lineups, AppDataScope.attendance},
            reason: 'lineup',
          ),
          _RealtimeBindingPlan(
            table: 'lineup_players',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'club_id',
              value: clubId,
            ),
            scopes: {AppDataScope.lineups, AppDataScope.attendance},
            reason: 'lineup_player',
          ),
          _binding(
            table: 'attendance_weeks',
            filter: _eqFilter('club_id', clubId),
            scopes: {AppDataScope.attendance},
            reason: 'attendance_week',
          ),
          if (snapshot.canManageAttendanceAll)
            _binding(
              table: 'attendance_entries',
              filter: _eqFilter('club_id', clubId),
              scopes: {AppDataScope.attendance},
              reason: 'attendance_entry',
            )
          else if (snapshot.playerId != null && snapshot.playerId!.isNotEmpty)
            _binding(
              table: 'attendance_entries',
              filter: _eqFilter('player_id', snapshot.playerId!),
              scopes: {AppDataScope.attendance},
              reason: 'attendance_entry',
            ),
        ],
      ),
    );

    if (snapshot.isCaptain) {
      plans.add(
        _RealtimeChannelPlan(
          name: 'clubline:captain:$clubId',
          bindings: <_RealtimeBindingPlan>[
            _binding(
              table: 'join_requests',
              filter: _eqFilter('club_id', clubId),
              scopes: {AppDataScope.clubs, AppDataScope.players},
              reason: 'join_request',
            ),
            _binding(
              table: 'leave_requests',
              filter: _eqFilter('club_id', clubId),
              scopes: {AppDataScope.clubs, AppDataScope.players},
              reason: 'leave_request',
            ),
          ],
        ),
      );
    }

    return plans;
  }

  _RealtimeBindingPlan _binding({
    required String table,
    required Set<AppDataScope> scopes,
    required String reason,
    PostgresChangeFilter? filter,
  }) {
    return _RealtimeBindingPlan(
      table: table,
      scopes: scopes,
      reason: reason,
      filter: filter,
    );
  }

  PostgresChangeFilter _eqFilter(String column, String value) {
    return PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: column,
      value: value,
    );
  }

  void _subscribeSupabaseChannel(
    SupabaseClient client,
    _RealtimeChannelPlan plan,
  ) {
    var channel = client.channel(plan.name);
    for (final binding in plan.bindings) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: binding.table,
        filter: binding.filter,
        callback: (payload) => _handleSupabasePayload(binding, payload),
      );
    }

    _supabaseChannelHealthByName[plan.name] = _RealtimeChannelHealth.pending;
    channel.subscribe((status, error) {
      _handleSupabaseChannelStatus(
        channelName: plan.name,
        status: status,
        error: error,
      );
    });
    _supabaseChannelsByName[plan.name] = channel;
  }

  void _handleSupabaseChannelStatus({
    required String channelName,
    required RealtimeSubscribeStatus status,
    required Object? error,
  }) {
    if (!_supabaseChannelHealthByName.containsKey(channelName)) {
      return;
    }

    switch (status) {
      case RealtimeSubscribeStatus.subscribed:
        _supabaseChannelHealthByName[channelName] =
            _RealtimeChannelHealth.healthy;
        break;
      case RealtimeSubscribeStatus.channelError:
      case RealtimeSubscribeStatus.closed:
      case RealtimeSubscribeStatus.timedOut:
        _supabaseChannelHealthByName[channelName] =
            _RealtimeChannelHealth.unhealthy;
        debugPrint(
          'Supabase realtime channel $channelName changed status to ${status.name}: $error',
        );
        break;
    }

    _updateSupabaseTransportHealth();
  }

  void _handleSupabasePayload(
    _RealtimeBindingPlan binding,
    PostgresChangePayload payload,
  ) {
    if (binding.scopes.isEmpty) {
      return;
    }

    _updateAdaptiveBatchWindow();
    _pendingScopes.addAll(binding.scopes);
    _lastPendingReason = '${binding.reason}_${payload.eventType.name}';
    _scheduleDispatch();
  }

  void _handleRawLocalMessage(String payload) {
    dynamic decoded;
    try {
      decoded = jsonDecode(payload);
    } catch (_) {
      return;
    }

    if (decoded is! Map) {
      return;
    }

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

  AppDataScope? _mapScope(String rawScope) {
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
      case 'teamInfo':
        return AppDataScope.teamInfo;
      case 'vicePermissions':
        return AppDataScope.vicePermissions;
      default:
        return null;
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
        reason: 'realtime_$batchedReason',
      );
    });
  }

  void _updateAdaptiveBatchWindow() {
    final now = DateTime.now();
    _recentEventTimestamps.add(now);
    _recentEventTimestamps.removeWhere(
      (eventTime) => now.difference(eventTime) > _trafficObservationWindow,
    );

    if (_recentEventTimestamps.length >= _highTrafficEventsThreshold) {
      _lastHighTrafficDetectedAt = now;
      _currentBatchWindow = _highTrafficBatchWindow;
      return;
    }

    if (_currentBatchWindow == _highTrafficBatchWindow &&
        _lastHighTrafficDetectedAt != null &&
        now.difference(_lastHighTrafficDetectedAt!) >=
            _lowTrafficRecoveryWindow) {
      _currentBatchWindow = _baseBatchWindow;
    }
  }

  Future<void> _disconnectRealtime({bool disposeClient = false}) async {
    await _disconnectLocalRealtime();
    await _disconnectSupabaseChannels();
    if (disposeClient) {
      await _disposeSupabaseClient();
    }
    _transportConnected = false;
    _activeTransport = null;
  }

  Future<void> _disconnectLocalRealtime() async {
    await _localMessageSubscription?.cancel();
    _localMessageSubscription = null;
    appRealtimeBridge.disconnect();
  }

  Future<void> _disconnectSupabaseChannels() async {
    final client = _supabaseClient;
    if (client == null || _supabaseChannelsByName.isEmpty) {
      _supabaseChannelPlansByName.clear();
      _supabaseChannelHealthByName.clear();
      _reconnectingSupabaseChannelNames.clear();
      return;
    }

    final channels = List<RealtimeChannel>.from(_supabaseChannelsByName.values);
    _supabaseChannelsByName.clear();
    _supabaseChannelPlansByName.clear();
    _supabaseChannelHealthByName.clear();
    _reconnectingSupabaseChannelNames.clear();
    for (final channel in channels) {
      try {
        await client.removeChannel(channel);
      } catch (error) {
        debugPrint('Supabase realtime channel removal failed: $error');
      }
    }
  }

  Future<void> _disposeSupabaseClient() async {
    final client = _supabaseClient;
    _supabaseClient = null;
    _supabaseUrl = null;
    _supabaseAnonKey = null;
    if (client == null) {
      return;
    }

    try {
      await client.dispose();
    } catch (error) {
      debugPrint('Supabase client dispose failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  void _pollRealtimeHealth() {
    if (_disposed || _isConnecting) {
      return;
    }

    switch (_activeTransport) {
      case _RealtimeTransportMode.local:
        if (!_transportConnected) {
          unawaited(_syncRealtimeBinding(force: true));
        }
        return;
      case _RealtimeTransportMode.supabase:
        if (_supabaseChannelPlansByName.isEmpty ||
            _supabaseChannelsByName.isEmpty) {
          unawaited(_syncRealtimeBinding(force: true));
          return;
        }

        final unhealthyChannelNames = _currentUnhealthySupabaseChannelNames();
        if (unhealthyChannelNames.isEmpty) {
          return;
        }

        if (_hasHealthySupabaseChannels || _hasPendingSupabaseChannels) {
          unawaited(_reconnectSupabaseChannels(unhealthyChannelNames));
          return;
        }

        unawaited(_syncRealtimeBinding(force: true));
        return;
      case null:
        if (!_transportConnected) {
          unawaited(_syncRealtimeBinding(force: true));
        }
        return;
    }
  }

  Future<void> _reconnectSupabaseChannels(Set<String> channelNames) async {
    final client = _supabaseClient;
    if (client == null || channelNames.isEmpty) {
      return;
    }

    for (final channelName in channelNames) {
      if (_reconnectingSupabaseChannelNames.contains(channelName)) {
        continue;
      }

      final plan = _supabaseChannelPlansByName[channelName];
      if (plan == null) {
        continue;
      }

      _reconnectingSupabaseChannelNames.add(channelName);
      try {
        final existingChannel = _supabaseChannelsByName.remove(channelName);
        _supabaseChannelHealthByName[channelName] =
            _RealtimeChannelHealth.pending;
        _updateSupabaseTransportHealth();

        if (existingChannel != null) {
          try {
            await client.removeChannel(existingChannel);
          } catch (error) {
            debugPrint(
              'Supabase realtime channel targeted removal failed for $channelName: $error',
            );
          }
        }

        if (_disposed || _activeTransport != _RealtimeTransportMode.supabase) {
          continue;
        }

        _subscribeSupabaseChannel(client, plan);
        _updateSupabaseTransportHealth();
      } finally {
        _reconnectingSupabaseChannelNames.remove(channelName);
      }
    }
  }

  Set<String> _currentUnhealthySupabaseChannelNames() {
    final names = <String>{};
    for (final entry in _supabaseChannelHealthByName.entries) {
      if (entry.value == _RealtimeChannelHealth.unhealthy) {
        names.add(entry.key);
      }
    }
    return names;
  }

  bool get _hasHealthySupabaseChannels {
    return _supabaseChannelHealthByName.values.contains(
      _RealtimeChannelHealth.healthy,
    );
  }

  bool get _hasPendingSupabaseChannels {
    return _supabaseChannelHealthByName.values.contains(
      _RealtimeChannelHealth.pending,
    );
  }

  void _updateSupabaseTransportHealth() {
    if (_activeTransport != _RealtimeTransportMode.supabase &&
        _supabaseChannelHealthByName.isEmpty) {
      return;
    }

    _transportConnected =
        _supabaseChannelHealthByName.isNotEmpty &&
        (_hasHealthySupabaseChannels || _hasPendingSupabaseChannels);
  }
}

String? _normalizeEntityId(dynamic value) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}
