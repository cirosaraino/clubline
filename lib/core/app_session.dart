import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/auth_repository.dart';
import '../data/club_repository.dart';
import '../data/player_repository.dart';
import '../data/profile_setup_draft_store.dart';
import '../data/team_info_repository.dart';
import '../data/vice_permissions_repository.dart';
import '../models/authenticated_user.dart';
import '../models/club.dart';
import '../models/join_request.dart';
import '../models/leave_request.dart';
import '../models/membership.dart';
import '../models/player_profile.dart';
import '../models/team_info.dart';
import '../models/vice_permissions.dart';
import 'app_data_sync.dart';
import 'player_formatters.dart';

class AppSessionController extends ChangeNotifier {
  AppSessionController({this.onTeamInfoChanged})
    : _authRepository = AuthRepository(),
      _clubRepository = ClubRepository(),
      _playerRepository = PlayerRepository(),
      _teamInfoRepository = TeamInfoRepository(),
      _vicePermissionsRepository = VicePermissionsRepository() {
    AppDataSync.instance.addListener(_handleAppDataSync);
    refresh();
  }

  final void Function(TeamInfo teamInfo)? onTeamInfoChanged;
  final AuthRepository _authRepository;
  final ClubRepository _clubRepository;
  final PlayerRepository _playerRepository;
  final TeamInfoRepository _teamInfoRepository;
  final VicePermissionsRepository _vicePermissionsRepository;

  AuthenticatedUser? _authUser;
  Club? _currentClub;
  Membership? _membership;
  JoinRequest? _pendingJoinRequest;
  LeaveRequest? _pendingLeaveRequest;
  List<JoinRequest> _captainPendingJoinRequests = const [];
  List<LeaveRequest> _captainPendingLeaveRequests = const [];
  List<PlayerProfile> _players = const [];
  ProfileSetupDraft? _profileSetupDraft;
  TeamInfo _teamInfo = TeamInfo.defaults;
  VicePermissions _vicePermissions = VicePermissions.defaults;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _refreshQueued = false;
  String? _errorMessage;
  int _lastHandledSyncRevision = 0;
  bool _disposed = false;

  List<PlayerProfile> get players => _players;
  ProfileSetupDraft? get profileSetupDraft => _profileSetupDraft;
  TeamInfo get teamInfo => _teamInfo;
  VicePermissions get vicePermissions => _vicePermissions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AuthenticatedUser? get authUser => _authUser;
  bool get isAuthenticated => _authUser != null;
  String? get currentUserEmail => _authUser?.email.trim();
  Club? get currentClub => _currentClub;
  Membership? get membership => _membership;
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
      isAuthenticated && !hasClubMembership && !hasPendingJoinRequest;
  bool get needsProfileSetup =>
      hasClubMembership &&
      (currentUser == null || currentUser!.needsProfileCompletion);
  bool get requiresPasswordRecovery =>
      _authRepository.currentSession?.isRecoverySession == true;
  bool get isCaptainRegistrationOpen => false;
  bool get canBootstrapCaptain => false;
  bool get isEmailVerified => _authUser?.emailVerified == true;

  PlayerProfile? get currentUser {
    final authUser = _authUser;
    if (authUser == null) {
      return null;
    }

    for (final player in _players) {
      if (player.isLinkedToAuthUser(authUser.id)) {
        return player;
      }
    }

    for (final player in _players) {
      if (player.matchesAccountEmail(authUser.email)) {
        return player;
      }
    }

    return null;
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final session = await _authRepository.signInWithEmail(
      email: email,
      password: password,
    );
    _authUser = session.user;
    _errorMessage = null;
    _notifyIfMounted();
    await refresh(showLoadingState: false);
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final session = await _authRepository.signUpWithEmail(
      email: email,
      password: password,
    );
    _authUser = session?.user;
    _errorMessage = null;
    _notifyIfMounted();
    await refresh(showLoadingState: false);
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

  Future<void> refresh({bool showLoadingState = true}) async {
    if (_isRefreshing) {
      _refreshQueued = true;
      return;
    }

    _isRefreshing = true;
    if (showLoadingState) {
      _isLoading = true;
    }
    _errorMessage = null;
    _notifyIfMounted();

    try {
      _authUser = await _authRepository.restoreSession();

      if (_authUser == null) {
        _resetAuthenticatedState();
        return;
      }

      _profileSetupDraft = await ProfileSetupDraftStore.instance.loadForAccount(
        _authUser?.email,
      );

      final membershipFuture = _clubRepository.fetchCurrentMembership();
      final clubFuture = _clubRepository.fetchCurrentClub();
      final pendingJoinRequestFuture = _clubRepository
          .fetchCurrentPendingJoinRequest();

      final membership = await membershipFuture;
      final currentClub = await clubFuture;
      final pendingJoinRequest = await pendingJoinRequestFuture;

      _membership = membership;
      _currentClub = currentClub;
      _pendingJoinRequest = pendingJoinRequest;

      if (!hasClubMembership) {
        _pendingLeaveRequest = null;
        _captainPendingJoinRequests = const [];
        _captainPendingLeaveRequests = const [];
        _players = const [];
        _vicePermissions = VicePermissions.defaults;
        _teamInfo = TeamInfo.defaults;
        _isLoading = false;
        onTeamInfoChanged?.call(_teamInfo);
        _notifyIfMounted();
        return;
      }

      _teamInfo = _fallbackTeamInfoForClub(currentClub!);
      final loadedPlayersFuture = _playerRepository.fetchPlayers();
      final loadedTeamInfoFuture = _loadOptionalData<TeamInfo>(
        _teamInfoRepository.fetchTeamInfo(),
        fallback: _teamInfo,
        label: 'team_info',
      );
      final loadedVicePermissionsFuture = _loadOptionalData<VicePermissions>(
        _vicePermissionsRepository.fetchPermissions(),
        fallback: VicePermissions.defaults,
        label: 'vice_permissions',
      );
      final pendingLeaveRequestFuture = _loadOptionalData<LeaveRequest?>(
        _clubRepository.fetchCurrentPendingLeaveRequest(),
        fallback: null,
        label: 'current_pending_leave_request',
      );
      final captainJoinRequestsFuture = membership!.isCaptain
          ? _loadOptionalData<List<JoinRequest>>(
              _clubRepository.fetchPendingJoinRequests(),
              fallback: const [],
              label: 'captain_pending_join_requests',
            )
          : Future<List<JoinRequest>>.value(const []);
      final captainLeaveRequestsFuture = membership.isCaptain
          ? _loadOptionalData<List<LeaveRequest>>(
              _clubRepository.fetchPendingLeaveRequests(),
              fallback: const [],
              label: 'captain_pending_leave_requests',
            )
          : Future<List<LeaveRequest>>.value(const []);

      final loadedPlayers = await loadedPlayersFuture;
      final loadedTeamInfo = await loadedTeamInfoFuture;
      final loadedVicePermissions = await loadedVicePermissionsFuture;
      final pendingLeaveRequest = await pendingLeaveRequestFuture;
      final captainJoinRequests = await captainJoinRequestsFuture;
      final captainLeaveRequests = await captainLeaveRequestsFuture;

      _pendingLeaveRequest = pendingLeaveRequest;
      _captainPendingJoinRequests = captainJoinRequests;
      _captainPendingLeaveRequests = captainLeaveRequests;
      _teamInfo = loadedTeamInfo;
      _vicePermissions = loadedVicePermissions;
      _players = loadedPlayers
          .map(
            (player) => player.copyWith(vicePermissions: loadedVicePermissions),
          )
          .toList();
      await _syncDraftIntoCurrentUserIfNeeded();
      _isLoading = false;
      _errorMessage = null;
      onTeamInfoChanged?.call(_teamInfo);
      _notifyIfMounted();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      _notifyIfMounted();
    } finally {
      _isRefreshing = false;
      if (_refreshQueued) {
        _refreshQueued = false;
        unawaited(refresh(showLoadingState: false));
      }
    }
  }

  Future<T> _loadOptionalData<T>(
    Future<T> future, {
    required T fallback,
    required String label,
  }) async {
    try {
      return await future;
    } catch (error) {
      debugPrint('AppSession optional fetch failed for $label: $error');
      return fallback;
    }
  }

  Future<void> _syncDraftIntoCurrentUserIfNeeded() async {
    final draft = _profileSetupDraft;
    final player = currentUser;
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
      await _playerRepository.updatePlayer(
        player.copyWith(
          nome: draft.nome,
          cognome: draft.cognome,
          accountEmail: player.accountEmail ?? _authUser?.email,
          shirtNumber: draft.shirtNumber,
          primaryRole: draft.primaryRole,
          secondaryRoles: normalizedDraftSecondaryRoles,
          idConsole: draft.idConsole,
        ),
      );

      final refreshedPlayers = await _playerRepository.fetchPlayers();
      _players = refreshedPlayers
          .map((current) => current.copyWith(vicePermissions: _vicePermissions))
          .toList();
    } catch (error) {
      debugPrint('AppSession draft sync failed: $error');
    }
  }

  TeamInfo _fallbackTeamInfoForClub(Club club) {
    return TeamInfo(
      id: club.id is num ? (club.id as num).toInt() : 1,
      teamName: club.name,
      crestUrl: club.logoUrl,
      slug: club.slug,
      primaryColor: club.primaryColor,
      accentColor: club.accentColor,
      surfaceColor: club.surfaceColor,
    );
  }

  void _resetAuthenticatedState() {
    _authUser = null;
    _currentClub = null;
    _membership = null;
    _pendingJoinRequest = null;
    _pendingLeaveRequest = null;
    _captainPendingJoinRequests = const [];
    _captainPendingLeaveRequests = const [];
    _players = const [];
    _profileSetupDraft = null;
    _teamInfo = TeamInfo.defaults;
    _vicePermissions = VicePermissions.defaults;
    _isLoading = false;
    _errorMessage = null;
    onTeamInfoChanged?.call(_teamInfo);
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
      AppDataScope.teamInfo,
      AppDataScope.vicePermissions,
    })) {
      return;
    }

    _lastHandledSyncRevision = change.revision;
    unawaited(refresh(showLoadingState: false));
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
