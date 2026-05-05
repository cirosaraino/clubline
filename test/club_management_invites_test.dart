import 'package:clubline/core/app_session.dart';
import 'package:clubline/data/api_client.dart';
import 'package:clubline/data/auth_repository.dart';
import 'package:clubline/data/club_invites_repository.dart';
import 'package:clubline/data/player_repository.dart';
import 'package:clubline/models/authenticated_user.dart';
import 'package:clubline/models/club.dart';
import 'package:clubline/models/club_invite.dart';
import 'package:clubline/models/cursor_pagination.dart';
import 'package:clubline/models/invite_candidate.dart';
import 'package:clubline/models/membership.dart';
import 'package:clubline/models/player_profile.dart';
import 'package:clubline/models/resolved_session_state.dart';
import 'package:clubline/models/vice_permissions.dart';
import 'package:clubline/ui/pages/club_management_page.dart';
import 'package:clubline/ui/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _waitForController(AppSessionController controller) async {
  while (controller.isSessionGateResolving ||
      controller.isLoading ||
      controller.isLoadingPlayers) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<void> _pumpWithSession(
  WidgetTester tester, {
  required AppSessionController controller,
  required Widget child,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AppSessionScope(controller: controller, child: child),
    ),
  );
  await _waitForController(controller);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Club management invites UI', () {
    testWidgets('shows the invites section when canManageInvites is true', (
      tester,
    ) async {
      final state = _InviteManagementState(
        currentPlayer: _staffPlayer(manageInvites: true),
        roster: [_staffPlayer(manageInvites: true)],
      );
      final controller = _buildController(state);
      final repository = _FakeClubInvitesRepository(state);
      addTearDown(controller.dispose);

      await _pumpWithSession(
        tester,
        controller: controller,
        child: ClubManagementPage(clubInvitesRepository: repository),
      );

      expect(
        find.byKey(const Key('club-management-invites-section')),
        findsOneWidget,
      );
    });

    testWidgets(
      'does not show the invites section when canManageInvites is false',
      (tester) async {
        final player = _plainPlayer();
        final state = _InviteManagementState(
          currentPlayer: player,
          roster: [player],
        );
        final controller = _buildController(state);
        final repository = _FakeClubInvitesRepository(state);
        addTearDown(controller.dispose);

        await _pumpWithSession(
          tester,
          controller: controller,
          child: ClubManagementPage(clubInvitesRepository: repository),
        );

        expect(
          find.byKey(const Key('club-management-invites-section')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('club-management-no-access-state')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'does not show the invites section when managePlayers is true but manageInvites is false',
      (tester) async {
        final player = _staffPlayer(
          managePlayers: true,
          manageInvites: false,
        );
        final state = _InviteManagementState(
          currentPlayer: player,
          roster: [player],
        );
        final controller = _buildController(state);
        final repository = _FakeClubInvitesRepository(state);
        addTearDown(controller.dispose);

        await _pumpWithSession(
          tester,
          controller: controller,
          child: ClubManagementPage(clubInvitesRepository: repository),
        );

        expect(
          find.byKey(const Key('club-management-invites-section')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('club-management-no-access-state')),
          findsOneWidget,
        );
      },
    );

    testWidgets('renders pending invites first and shows all when requested', (
      tester,
    ) async {
      final state = _InviteManagementState(
        currentPlayer: _staffPlayer(manageInvites: true),
        roster: [_staffPlayer(manageInvites: true)],
        sentInvites: [
          _sentInviteFixture(
            id: 11,
            nome: 'Mario',
            cognome: 'Rossi',
            status: ClubInviteStatus.pending,
          ),
          _sentInviteFixture(
            id: 12,
            nome: 'Luigi',
            cognome: 'Verdi',
            status: ClubInviteStatus.revoked,
          ),
        ],
      );
      final controller = _buildController(state);
      final repository = _FakeClubInvitesRepository(state);
      addTearDown(controller.dispose);

      await _pumpWithSession(
        tester,
        controller: controller,
        child: ClubManagementPage(clubInvitesRepository: repository),
      );

      expect(find.text('Mario Rossi'), findsOneWidget);
      expect(find.text('Luigi Verdi'), findsNothing);

      await tester.tap(find.text('Tutti'));
      await tester.pumpAndSettle();

      expect(find.text('Luigi Verdi'), findsOneWidget);
    });

    testWidgets('searches candidates and sends a new invite', (tester) async {
      final state = _InviteManagementState(
        currentPlayer: _staffPlayer(manageInvites: true),
        roster: [_staffPlayer(manageInvites: true)],
        availableCandidates: [
          const InviteCandidate(
            userId: 'candidate-1',
            playerProfileId: 31,
            nome: 'Luigi',
            cognome: 'Verdi',
            idConsole: 'luigi-10',
            primaryRole: 'ATT',
            invitable: true,
          ),
        ],
      );
      final controller = _buildController(state);
      final repository = _FakeClubInvitesRepository(state);
      addTearDown(controller.dispose);

      await _pumpWithSession(
        tester,
        controller: controller,
        child: ClubManagementPage(clubInvitesRepository: repository),
      );

      await tester.tap(
        find.byKey(const Key('club-management-open-invite-player')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('invite-player-search-field')),
        'lu',
      );
      await tester.tap(find.byKey(const Key('invite-player-search-button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('invite-candidate-card-candidate-1')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const Key('invite-candidate-action-candidate-1')),
      );
      await tester.tap(
        find.byKey(const Key('invite-candidate-action-candidate-1')),
      );
      await tester.pumpAndSettle();

      expect(repository.createdUserIds, ['candidate-1']);
      expect(find.text('Luigi Verdi'), findsOneWidget);
    });

    testWidgets('revokes a pending invite and updates the list', (
      tester,
    ) async {
      final state = _InviteManagementState(
        currentPlayer: _staffPlayer(manageInvites: true),
        roster: [_staffPlayer(manageInvites: true)],
        sentInvites: [
          _sentInviteFixture(
            id: 11,
            nome: 'Mario',
            cognome: 'Rossi',
            status: ClubInviteStatus.pending,
          ),
        ],
      );
      final controller = _buildController(state);
      final repository = _FakeClubInvitesRepository(state);
      addTearDown(controller.dispose);

      await _pumpWithSession(
        tester,
        controller: controller,
        child: ClubManagementPage(clubInvitesRepository: repository),
      );

      await tester.ensureVisible(
        find.byKey(const Key('club-management-revoke-invite-11')),
      );
      await tester.tap(
        find.byKey(const Key('club-management-revoke-invite-11')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('club-management-revoke-confirm')));
      await tester.pumpAndSettle();

      expect(repository.revokedInviteIds, ['11']);
      expect(
        find.byKey(const Key('club-management-sent-invites-empty-state')),
        findsOneWidget,
      );
    });

    testWidgets('shows a clear message when createInvite hits a duplicate', (
      tester,
    ) async {
      final state = _InviteManagementState(
        currentPlayer: _staffPlayer(manageInvites: true),
        roster: [_staffPlayer(manageInvites: true)],
        availableCandidates: [
          const InviteCandidate(
            userId: 'candidate-1',
            playerProfileId: 31,
            nome: 'Luigi',
            cognome: 'Verdi',
            invitable: true,
          ),
        ],
        createInviteError: const ApiException(
          'pending_club_invite_exists',
          statusCode: 409,
          code: 'pending_club_invite_exists',
        ),
      );
      final controller = _buildController(state);
      final repository = _FakeClubInvitesRepository(state);
      addTearDown(controller.dispose);

      await _pumpWithSession(
        tester,
        controller: controller,
        child: ClubManagementPage(clubInvitesRepository: repository),
      );

      await tester.tap(
        find.byKey(const Key('club-management-open-invite-player')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('invite-player-search-field')),
        'lu',
      );
      await tester.tap(find.byKey(const Key('invite-player-search-button')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('invite-candidate-action-candidate-1')),
      );
      await tester.tap(
        find.byKey(const Key('invite-candidate-action-candidate-1')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Esiste gia un invito pendente per questo player nel club.'),
        findsOneWidget,
      );
      expect(find.text('pending_club_invite_exists'), findsNothing);
      expect(find.byKey(const Key('invite-player-page')), findsOneWidget);
    });

    testWidgets(
      'does not show the invites entry point when managePlayers is true but manageInvites is false',
      (tester) async {
        final player = _staffPlayer(
          managePlayers: true,
          manageInvites: false,
        );
        final state = _InviteManagementState(
          currentPlayer: player,
          roster: [player],
        );
        final controller = _buildController(state);
        addTearDown(controller.dispose);

        await _pumpWithSession(
          tester,
          controller: controller,
          child: _buildHomePage(),
        );

        await tester.tap(find.byKey(const Key('home-profile-menu-button')));
        await tester.pumpAndSettle();

        expect(find.text('Gestione inviti club'), findsNothing);
      },
    );
  });
}

AppSessionController _buildController(_InviteManagementState state) {
  return AppSessionController(
    authRepository: _FakeAuthRepository(
      stateBuilder: () => ResolvedSessionState(
        user: const AuthenticatedUser(id: 'user-1', email: 'staff@example.com'),
        membership: Membership(
          id: 101,
          clubId: 1,
          role: state.currentPlayer.teamRole,
          status: 'active',
        ),
        club: const Club(id: 1, name: 'Club Uno', slug: 'club-uno'),
        currentPlayer: state.currentPlayer,
        vicePermissions: state.currentPlayer.vicePermissions,
      ),
    ),
    playerRepository: _FakePlayerRepository(state.roster),
  );
}

HomePage _buildHomePage() {
  return HomePage(
    onOpenCreateProfile: () {},
    onOpenEditCurrentProfile: () {},
    onOpenSignIn: () {},
    onOpenSignUp: () {},
    onOpenPasswordSettings: () {},
    onOpenBiometricSettings: () {},
    onOpenClubManagement: () {},
    onOpenThemeSettings: () {},
    onOpenClubInfoSettings: () {},
    onOpenVicePermissionsSettings: () {},
    onDeleteAccount: () async {},
  );
}

PlayerProfile _staffPlayer({
  required bool manageInvites,
  bool managePlayers = false,
}) {
  return PlayerProfile(
    id: 7,
    clubId: 1,
    membershipId: 101,
    nome: 'Vice',
    cognome: 'Staff',
    authUserId: 'user-1',
    accountEmail: 'staff@example.com',
    shirtNumber: 8,
    primaryRole: 'CDC',
    secondaryRoles: const ['CC'],
    idConsole: 'vice-8',
    teamRole: 'vice_captain',
    vicePermissions: VicePermissions(
      managePlayers: managePlayers,
      manageInvites: manageInvites,
    ),
  );
}

PlayerProfile _plainPlayer() {
  return const PlayerProfile(
    id: 9,
    clubId: 1,
    membershipId: 102,
    nome: 'Mario',
    cognome: 'Rossi',
    authUserId: 'user-1',
    accountEmail: 'player@example.com',
    shirtNumber: 10,
    primaryRole: 'ATT',
    idConsole: 'mario-10',
    teamRole: 'player',
  );
}

ClubInvite _sentInviteFixture({
  required dynamic id,
  required String nome,
  required String cognome,
  required ClubInviteStatus status,
}) {
  return ClubInvite(
    id: id,
    clubId: 1,
    club: const Club(id: 1, name: 'Club Uno', slug: 'club-uno'),
    createdByUserId: 'captain-1',
    createdByMembershipId: 101,
    targetUserId: 'target-$id',
    targetPlayerProfileId: 77,
    targetAccountEmail: '$nome@example.com',
    targetNome: nome,
    targetCognome: cognome,
    targetIdConsole: '${nome.toLowerCase()}-7',
    targetPrimaryRole: 'ATT',
    status: status,
    createdAt: DateTime(2026, 5, 5, 12, 0),
  );
}

class _InviteManagementState {
  _InviteManagementState({
    required this.currentPlayer,
    required this.roster,
    this.sentInvites = const [],
    this.availableCandidates = const [],
    this.createInviteError,
  });

  final PlayerProfile currentPlayer;
  final List<PlayerProfile> roster;
  List<ClubInvite> sentInvites;
  final List<InviteCandidate> availableCandidates;
  final ApiException? createInviteError;
}

class _FakeClubInvitesRepository extends ClubInvitesRepository {
  _FakeClubInvitesRepository(this.state);

  final _InviteManagementState state;
  final List<String> createdUserIds = <String>[];
  final List<String> revokedInviteIds = <String>[];
  int _nextInviteId = 200;

  @override
  Future<ClubInviteListResult> getSentInvites({
    ClubInviteListStatus status = ClubInviteListStatus.pending,
    int limit = 20,
    int? cursor,
  }) async {
    final filteredInvites = status == ClubInviteListStatus.pending
        ? state.sentInvites
              .where((invite) => invite.isPending)
              .toList(growable: false)
        : List<ClubInvite>.from(state.sentInvites);

    return ClubInviteListResult(
      invites: filteredInvites,
      pagination: CursorPagination(
        limit: limit,
        hasMore: false,
        nextCursor: null,
      ),
    );
  }

  @override
  Future<List<InviteCandidate>> searchCandidates(
    String query, {
    int limit = 20,
  }) async {
    final normalizedQuery = query.trim().toLowerCase();
    return state.availableCandidates
        .where(
          (candidate) =>
              candidate.fullName.toLowerCase().contains(normalizedQuery) ||
              (candidate.idConsole ?? '').toLowerCase().contains(
                normalizedQuery,
              ),
        )
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<ClubInvite> createInvite(String targetUserId) async {
    if (state.createInviteError != null) {
      throw state.createInviteError!;
    }

    createdUserIds.add(targetUserId);
    final candidate = state.availableCandidates.firstWhere(
      (entry) => entry.userId == targetUserId,
    );
    final invite = ClubInvite(
      id: _nextInviteId,
      clubId: 1,
      club: const Club(id: 1, name: 'Club Uno', slug: 'club-uno'),
      createdByUserId: 'user-1',
      createdByMembershipId: 101,
      targetUserId: candidate.userId,
      targetPlayerProfileId: candidate.playerProfileId,
      targetAccountEmail: candidate.accountEmail,
      targetNome: candidate.nome,
      targetCognome: candidate.cognome,
      targetIdConsole: candidate.idConsole,
      targetPrimaryRole: candidate.primaryRole,
      status: ClubInviteStatus.pending,
      createdAt: DateTime(2026, 5, 5, 12, 30),
    );
    _nextInviteId += 1;
    state.sentInvites = [invite, ...state.sentInvites];
    return invite;
  }

  @override
  Future<ClubInvite> revokeInvite(dynamic inviteId) async {
    revokedInviteIds.add('$inviteId');
    final index = state.sentInvites.indexWhere(
      (invite) => '${invite.id}' == '$inviteId',
    );
    final updatedInvite = state.sentInvites[index].copyWith(
      status: ClubInviteStatus.revoked,
      resolvedAt: DateTime(2026, 5, 5, 13, 0),
    );
    state.sentInvites[index] = updatedInvite;
    return updatedInvite;
  }
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({required this.stateBuilder});

  final ResolvedSessionState Function() stateBuilder;

  @override
  Future<void> warmUpBackend() async {}

  @override
  Future<ResolvedSessionState?> resolveSessionState() async {
    return stateBuilder();
  }
}

class _FakePlayerRepository extends PlayerRepository {
  _FakePlayerRepository(this.players);

  final List<PlayerProfile> players;

  @override
  Future<List<PlayerProfile>> fetchPlayers() async {
    return players;
  }
}
