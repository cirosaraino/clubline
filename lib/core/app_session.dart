import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/auth_repository.dart';
import '../data/player_repository.dart';
import '../data/profile_setup_draft_store.dart';
import '../models/authenticated_user.dart';
import '../models/club.dart';
import '../models/club_info.dart';
import '../models/join_request.dart';
import '../models/leave_request.dart';
import '../models/membership.dart';
import '../models/player_profile.dart';
import '../models/resolved_session_state.dart';
import '../models/vice_permissions.dart';
import 'app_data_sync.dart';
import 'app_session_gate.dart';
import 'player_formatters.dart';

enum AppSessionResolutionTrigger { bootstrap, signIn, signUp, retry, refresh }

enum AppSessionResolutionPhase { idle, restoringSession, fetchingSessionState }

class AppSessionController extends ChangeNotifier {
  AppSessionController({
    this.onClubInfoChanged,
    AuthRepository? authRepository,
    PlayerRepository? playerRepository,
  }) : _authRepository = authRepository ?? AuthRepository(),
       _playerRepository = playerRepository ?? PlayerRepository() {
    AppDataSync.instance.addListener(_handleAppDataSync);
    unawaited(_authRepository.warmUpBackend());
    unawaited(refresh(trigger: AppSessionResolutionTrigger.bootstrap));
  }

  final void Function(ClubInfo clubInfo)? onClubInfoChanged;
  final AuthRepository _authRepository;
  final PlayerRepository _playerRepository;

  AuthenticatedUser? _authUser;
  Club? _currentClub;
  Membership? _membership;
  PlayerProfile? _currentPlayer;
  JoinRequest? _pendingJoinRequest;
  LeaveRequest? _pendingLeaveRequest;
  List<JoinRequest> _captainPendingJoinRequests = const [];
  List<LeaveRequest> _captainPendingLeaveRequests = const [];
  List<PlayerProfile> _players = const [];
  Future<void>? _playersLoadOperation;
  ProfileSetupDraft? _profileSetupDraft;
  ClubInfo _clubInfo = ClubInfo.defaults;
  VicePermissions _vicePermissions = VicePermissions.defaults;
  bool _isLoading = false;
  bool _isLoadingPlayers = false;
  bool _hasResolvedPlayers = false;
  bool _isRefreshing = false;
  bool _refreshQueued = false;
  bool _queuedShowLoadingState = false;
  AppSessionResolutionTrigger? _queuedTrigger;
  String? _errorMessage;
  String? _sessionGateErrorMessage;
  int _lastHandledSyncRevision = 0;
  bool _disposed = false;
  bool _isSessionGateResolving = true;
  AppSessionResolutionPhase _resolutionPhase =
      AppSessionResolutionPhase.restoringSession;
  AppSessionResolutionTrigger _resolutionTrigger =
      AppSessionResolutionTrigger.bootstrap;

  List<PlayerProfile> get players => _players;
  ProfileSetupDraft? get profileSetupDraft => _profileSetupDraft;
  ClubInfo get clubInfo => _clubInfo;
  VicePermissions get vicePermissions => _vicePermissions;
  bool get isLoading => _isLoading;
  bool get isLoadingPlayers => _isLoadingPlayers;
  bool get hasResolvedPlayers => _hasResolvedPlayers;
  String? get errorMessage => _errorMessage;
  String? get sessionGateErrorMessage => _sessionGateErrorMessage;
  AuthenticatedUser? get authUser => _authUser;
  bool get isAuthenticated => _authUser != null;
  String? get currentUserEmail => _authUser?.email.trim();
  Club? get currentClub => _currentClub;
  Membership? get membership => _membership;
  PlayerProfile? get currentUser => _currentPlayer;
  JoinRequest? get pendingJoinRequest => _pendingJoinRequest;
  LeaveRequest? get pendingLeaveRequest => _pendingLeaveRequest;
  List<JoinRequest> get captainPendingJoinRequests =>
      _captainPendingJoinRequests;
  List<LeaveRequest> get captainPendingLeaveRequests =>
      _captainPendingLeaveRequests;
  bool get hasClubMembership =>
      _membership?.isActive == true && _currentClub != null;
  bool get hasPendingJoinRequest => _pendingJoinRequest?.isPending == true;
  bool get hasPendingLeaveRequest => _pendingLeaveRequest?.isPending == true;
  bool get hasPlayerIdentityDraft => _profileSetupDraft?.isValid == true;
  bool get needsPlayerIdentitySetup =>
      isAuthenticated &&
      !hasClubMembership &&
      !hasPendingJoinRequest &&
      !hasPlayerIdentityDraft;
  bool get needsClubSelection =>
      sessionGateKind == AppSessionGateKind.authenticatedNeedsClubSelection;
  bool get needsProfileSetup =>
      sessionGateKind == AppSessionGateKind.authenticatedNeedsPlayerProfile;
  bool get isResolvingCurrentUserProfile =>
      hasClubMembership &&
      sessionGateKind == AppSessionGateKind.resolving &&
      (_currentPlayer == null || _currentPlayer!.needsProfileCompletion);
  bool get requiresPasswordRecovery =>
      _authRepository.currentSession?.isRecoverySession == true;
  bool get isCaptainRegistrationOpen => false;
  bool get canBootstrapCaptain => false;
  bool get isEmailVerified => _authUser?.emailVerified == true;
  bool get shouldEnableRealtime =>
      sessionGateKind == AppSessionGateKind.authenticatedWithClub;
  bool get isSessionGateResolving => _isSessionGateResolving;
  AppSessionResolutionPhase get resolutionPhase => _resolutionPhase;
  AppSessionResolutionTrigger get resolutionTrigger => _resolutionTrigger;

  AppSessionGateKind get sessionGateKind {
    return resolveAppSessionGate(
      isResolving: _isSessionGateResolving,
      hasResolutionError: _sessionGateErrorMessage != null,
      isAuthenticated: isAuthenticated,
      hasClubMembership: hasClubMembership,
      hasPlayerIdentityDraft: hasPlayerIdentityDraft,
      hasCurrentPlayer: _currentPlayer != null,
      needsCurrentPlayerCompletion:
          _currentPlayer?.needsProfileCompletion == true,
    );
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _logTransition('auth started', {'mode': 'sign_in'});
    final session = await _authRepository.signInWithEmail(
      email: email,
      password: password,
    );
    _authUser = session.user;
    _beginSessionResolution(trigger: AppSessionResolutionTrigger.signIn);
    unawaited(refresh(trigger: AppSessionResolutionTrigger.signIn));
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    _logTransition('auth started', {'mode': 'sign_up'});
    final session = await _authRepository.signUpWithEmail(
      email: email,
      password: password,
    );
    _authUser = session?.user;
    _beginSessionResolution(trigger: AppSessionResolutionTrigger.signUp);
    unawaited(refresh(trigger: AppSessionResolutionTrigger.signUp));
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
    _resetAuthenticatedState();
  }

  Future<void> deleteAccount() async {
    await _authRepository.deleteAccount();
    await ProfileSetupDraftStore.instance.clear();
    _resetAuthenticatedState();
  }

  Future<String> requestPasswordReset({required String email}) {
    return _authRepository.requestPasswordReset(email: email);
  }

  Future<String> updatePassword({required String password}) async {
    final message = await _authRepository.updatePassword(password: password);
    unawaited(refresh(showLoadingState: false));
    return message;
  }

  Future<void> retrySessionResolution() {
    return refresh(trigger: AppSessionResolutionTrigger.retry);
  }

  Future<void> refresh({
    bool showLoadingState = true,
    AppSessionResolutionTrigger trigger = AppSessionResolutionTrigger.refresh,
  }) async {
    if (_isRefreshing) {
      _refreshQueued = true;
      _queuedShowLoadingState = _queuedShowLoadingState || showLoadingState;
      _queuedTrigger = showLoadingState ? trigger : _queuedTrigger;
      return;
    }

    _isRefreshing = true;
    if (showLoadingState) {
      _beginSessionResolution(trigger: trigger, notify: false);
    } else {
      _errorMessage = null;
    }
    _notifyIfMounted();

    try {
      _resolutionPhase = AppSessionResolutionPhase.fetchingSessionState;
      _notifyIfMounted();
      final resolvedState = await _authRepository.resolveSessionState();

      if (resolvedState == null) {
        _logTransition('Supabase session restored', {'authenticated': false});
        _resetAuthenticatedState();
        _logTransition('final route/state chosen', {
          'gate': AppSessionGateKind.unauthenticated.name,
        });
        return;
      }

      _logTransition('Supabase session restored', {'authenticated': true});

      _applyResolvedSessionState(resolvedState);
      _profileSetupDraft = await ProfileSetupDraftStore.instance.loadForAccount(
        _authUser?.email,
      );

      _logTransition('backend session/profile fetched', {
        'hasCurrentPlayer': _currentPlayer != null,
        'hasDraft': hasPlayerIdentityDraft,
      });
      _logTransition('membership resolved', {
        'hasClubMembership': hasClubMembership,
        'hasPendingJoinRequest': hasPendingJoinRequest,
        'hasPendingLeaveRequest': hasPendingLeaveRequest,
      });

      _isSessionGateResolving = false;
      _sessionGateErrorMessage = null;
      _resolutionPhase = AppSessionResolutionPhase.idle;
      final nextGate = sessionGateKind;
      _logTransition('final route/state chosen', {'gate': nextGate.name});

      if (nextGate == AppSessionGateKind.authenticatedWithClub) {
        _isLoading = false;
      } else {
        _players = const [];
        _hasResolvedPlayers = false;
        _isLoadingPlayers = false;
        _isLoading = false;
      }
      _notifyIfMounted();
    } catch (error) {
      if (showLoadingState) {
        _isSessionGateResolving = false;
        _sessionGateErrorMessage = error.toString();
        _isLoading = false;
        _resolutionPhase = AppSessionResolutionPhase.idle;
      } else {
        _errorMessage = error.toString();
        _isLoading = false;
      }
      _notifyIfMounted();
    } finally {
      _isRefreshing = false;
      if (_refreshQueued) {
        final queuedShowLoadingState = _queuedShowLoadingState;
        final queuedTrigger =
            _queuedTrigger ?? AppSessionResolutionTrigger.refresh;
        _refreshQueued = false;
        _queuedShowLoadingState = false;
        _queuedTrigger = null;
        unawaited(
          refresh(
            showLoadingState: queuedShowLoadingState,
            trigger: queuedTrigger,
          ),
        );
      }
    }
  }

  void _beginSessionResolution({
    required AppSessionResolutionTrigger trigger,
    bool notify = true,
  }) {
    _resolutionTrigger = trigger;
    _resolutionPhase = AppSessionResolutionPhase.restoringSession;
    _isSessionGateResolving = true;
    _sessionGateErrorMessage = null;
    _errorMessage = null;
    if (notify) {
      _notifyIfMounted();
    }
  }

  void _applyResolvedSessionState(ResolvedSessionState resolvedState) {
    final previousUserId = _authUser?.id;
    final previousClubId = _currentClub?.id;

    _authUser = resolvedState.user;
    _membership = resolvedState.membership;
    _currentClub = resolvedState.club;
    _currentPlayer = resolvedState.currentPlayer?.copyWith(
      vicePermissions: resolvedState.vicePermissions,
    );
    _pendingJoinRequest = resolvedState.pendingJoinRequest;
    _pendingLeaveRequest = resolvedState.pendingLeaveRequest;
    _captainPendingJoinRequests = resolvedState.captainPendingJoinRequests;
    _captainPendingLeaveRequests = resolvedState.captainPendingLeaveRequests;
    _vicePermissions = resolvedState.vicePermissions;
    _clubInfo =
        resolvedState.clubInfo ??
        (_currentClub == null
            ? ClubInfo.defaults
            : _fallbackClubInfoForClub(_currentClub!));

    if (!_sameEntityId(previousUserId, _authUser?.id) ||
        !_sameEntityId(previousClubId, _currentClub?.id)) {
      _players = const [];
      _hasResolvedPlayers = false;
      _isLoadingPlayers = false;
      _playersLoadOperation = null;
    } else if (_players.isNotEmpty) {
      _players = _players
          .map((player) => player.copyWith(vicePermissions: _vicePermissions))
          .toList(growable: false);
      _refreshCurrentUserFromPlayers();
    }

    onClubInfoChanged?.call(_clubInfo);
  }

  Future<void> ensurePlayersLoaded({bool forceRefresh = false}) async {
    if (!hasClubMembership) {
      _players = const [];
      _hasResolvedPlayers = false;
      _isLoadingPlayers = false;
      _notifyIfMounted();
      return;
    }

    if (!forceRefresh && _hasResolvedPlayers) {
      return;
    }

    final activeLoad = _playersLoadOperation;
    if (activeLoad != null) {
      return activeLoad;
    }

    final completer = Completer<void>();
    _playersLoadOperation = completer.future;
    final expectedUserId = _authUser?.id;
    final expectedClubId = _currentClub?.id;
    _isLoadingPlayers = true;
    _notifyIfMounted();

    try {
      final loadedPlayers = await _playerRepository.fetchPlayers();
      if (!_matchesSessionSnapshot(expectedUserId, expectedClubId)) {
        completer.complete();
        _playersLoadOperation = null;
        return;
      }

      _players = loadedPlayers
          .map((player) => player.copyWith(vicePermissions: _vicePermissions))
          .toList(growable: false);
      _hasResolvedPlayers = true;
      _isLoadingPlayers = false;
      _refreshCurrentUserFromPlayers();
      _notifyIfMounted();
      unawaited(_syncDraftIntoCurrentUserIfNeeded());
      _logTransition('players loaded', {'count': _players.length});
      completer.complete();
    } catch (error) {
      if (!_matchesSessionSnapshot(expectedUserId, expectedClubId)) {
        completer.complete();
        _playersLoadOperation = null;
        return;
      }

      _isLoadingPlayers = false;
      _notifyIfMounted();
      completer.completeError(error);
      rethrow;
    } finally {
      _playersLoadOperation = null;
    }
  }

  void _refreshCurrentUserFromPlayers() {
    final authUser = _authUser;
    if (authUser == null || _players.isEmpty) {
      return;
    }

    PlayerProfile? matchedPlayer = _currentPlayer == null
        ? null
        : _players.firstWhere(
            (player) => _sameEntityId(player.id, _currentPlayer!.id),
            orElse: () => const PlayerProfile(nome: '', cognome: ''),
          );

    if (matchedPlayer == null || matchedPlayer.id == null) {
      for (final player in _players) {
        if (player.isLinkedToAuthUser(authUser.id) ||
            player.matchesAccountEmail(authUser.email)) {
          matchedPlayer = player;
          break;
        }
      }
    }

    if (matchedPlayer == null ||
        matchedPlayer.id == null ||
        matchedPlayer.nome.isEmpty && matchedPlayer.cognome.isEmpty) {
      return;
    }

    _currentPlayer = matchedPlayer.copyWith(vicePermissions: _vicePermissions);
  }

  Future<void> _syncDraftIntoCurrentUserIfNeeded() async {
    final draft = _profileSetupDraft;
    final player = _currentPlayer;
    if (!hasClubMembership ||
        draft == null ||
        player == null ||
        player.id == null) {
      return;
    }

    final normalizedPlayerName = normalizePlayerName(player.nome);
    final normalizedPlayerSurname = normalizePlayerName(player.cognome);
    final normalizedDraftName = normalizePlayerName(draft.nome);
    final normalizedDraftSurname = normalizePlayerName(draft.cognome);
    final normalizedDraftSecondaryRoles = normalizeRoleCodes(
      draft.secondaryRoles.where((role) => role != draft.primaryRole),
    );
    final normalizedCurrentSecondaryRoles = normalizeRoleCodes(
      player.secondaryRoles.where((role) => role != player.primaryRole),
    );

    final shouldSync =
        normalizedPlayerName != normalizedDraftName ||
        normalizedPlayerSurname != normalizedDraftSurname ||
        (player.idConsole ?? '') != draft.idConsole ||
        player.shirtNumber != draft.shirtNumber ||
        (player.primaryRole ?? '') != (draft.primaryRole ?? '') ||
        !listEquals(
          normalizedCurrentSecondaryRoles,
          normalizedDraftSecondaryRoles,
        );
    if (!shouldSync) {
      return;
    }

    try {
      final updatedPlayer = player.copyWith(
        nome: draft.nome,
        cognome: draft.cognome,
        accountEmail: player.accountEmail ?? _authUser?.email,
        shirtNumber: draft.shirtNumber,
        primaryRole: draft.primaryRole,
        secondaryRoles: normalizedDraftSecondaryRoles,
        idConsole: draft.idConsole,
        vicePermissions: _vicePermissions,
      );
      await _playerRepository.updatePlayer(updatedPlayer);

      _currentPlayer = updatedPlayer;
      if (_players.isNotEmpty) {
        _players = _players
            .map(
              (current) => _sameEntityId(current.id, updatedPlayer.id)
                  ? updatedPlayer
                  : current,
            )
            .toList(growable: false);
      }
      _notifyIfMounted();
    } catch (error) {
      debugPrint('AppSession draft sync failed: $error');
    }
  }

  ClubInfo _fallbackClubInfoForClub(Club club) {
    return ClubInfo(
      id: club.id is num ? (club.id as num).toInt() : 1,
      clubName: club.name,
      crestUrl: club.logoUrl,
      slug: club.slug,
      primaryColor: club.primaryColor,
      accentColor: club.accentColor,
      surfaceColor: club.surfaceColor,
    );
  }

  bool _matchesSessionSnapshot(dynamic userId, dynamic clubId) {
    return _sameEntityId(_authUser?.id, userId) &&
        _sameEntityId(_currentClub?.id, clubId);
  }

  bool _sameEntityId(dynamic left, dynamic right) {
    return '$left' == '$right';
  }

  void _resetAuthenticatedState() {
    _authUser = null;
    _currentClub = null;
    _membership = null;
    _currentPlayer = null;
    _pendingJoinRequest = null;
    _pendingLeaveRequest = null;
    _captainPendingJoinRequests = const [];
    _captainPendingLeaveRequests = const [];
    _players = const [];
    _playersLoadOperation = null;
    _profileSetupDraft = null;
    _clubInfo = ClubInfo.defaults;
    _vicePermissions = VicePermissions.defaults;
    _isLoading = false;
    _isLoadingPlayers = false;
    _hasResolvedPlayers = false;
    _errorMessage = null;
    _sessionGateErrorMessage = null;
    _isSessionGateResolving = false;
    _resolutionPhase = AppSessionResolutionPhase.idle;
    onClubInfoChanged?.call(_clubInfo);
    _notifyIfMounted();
  }

  void _notifyIfMounted() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _handleAppDataSync() {
    final change = AppDataSync.instance.latestChange;
    if (change == null || change.revision == _lastHandledSyncRevision) {
      return;
    }
    if (!change.affects({
      AppDataScope.clubs,
      AppDataScope.players,
      AppDataScope.clubInfo,
      AppDataScope.vicePermissions,
    })) {
      return;
    }

    _lastHandledSyncRevision = change.revision;
    unawaited(_refreshFromDataChange(change.affects({AppDataScope.players})));
  }

  Future<void> _refreshFromDataChange(bool playersMayHaveChanged) async {
    await refresh(showLoadingState: false);
    if (playersMayHaveChanged && _hasResolvedPlayers && hasClubMembership) {
      try {
        await ensurePlayersLoaded(forceRefresh: true);
      } catch (_) {
        // Keep background sync best-effort for deferred data.
      }
    }
  }

  void _logTransition(String event, [Map<String, Object?> details = const {}]) {
    if (!kDebugMode) {
      return;
    }

    final renderedDetails = details.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(' ');
    if (renderedDetails.isEmpty) {
      debugPrint('AppSession $event');
      return;
    }

    debugPrint('AppSession $event $renderedDetails');
  }

  @override
  void dispose() {
    _disposed = true;
    AppDataSync.instance.removeListener(_handleAppDataSync);
    super.dispose();
  }
}

class AppSessionScope extends InheritedNotifier<AppSessionController> {
  const AppSessionScope({
    super.key,
    required AppSessionController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppSessionController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppSessionScope>();
    assert(scope != null, 'AppSessionScope non trovato nel widget tree.');
    return scope!.notifier!;
  }

  static AppSessionController read(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<AppSessionScope>();
    final scope = element?.widget as AppSessionScope?;
    assert(scope != null, 'AppSessionScope non trovato nel widget tree.');
    return scope!.notifier!;
  }
}
