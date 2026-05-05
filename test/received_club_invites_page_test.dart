import 'package:clubline/core/app_session.dart';
import 'package:clubline/data/auth_repository.dart';
import 'package:clubline/data/club_invites_repository.dart';
import 'package:clubline/data/notifications_repository.dart';
import 'package:clubline/models/app_notification.dart';
import 'package:clubline/models/authenticated_user.dart';
import 'package:clubline/models/club.dart';
import 'package:clubline/models/club_invite.dart';
import 'package:clubline/models/cursor_pagination.dart';
import 'package:clubline/models/membership.dart';
import 'package:clubline/models/player_profile.dart';
import 'package:clubline/models/resolved_session_state.dart';
import 'package:clubline/models/vice_permissions.dart';
import 'package:clubline/ui/pages/club_access_hub_page.dart';
import 'package:clubline/ui/pages/notifications_page.dart';
import 'package:clubline/ui/pages/received_club_invites_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _waitForController(AppSessionController controller) async {
  while (controller.isSessionGateResolving || controller.isLoading) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Received club invites UI', () {
    testWidgets('shows empty state when there are no invites', (tester) async {
      final sessionState = _MutableSessionState();
      final controller = _buildController(sessionState);
      final repository = _FakeClubInvitesRepository(sessionState);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrapWithSession(
          controller,
          ReceivedClubInvitesPage(repository: repository),
        ),
      );
      await _waitForController(controller);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('received-invites-empty-state')),
        findsOneWidget,
      );
      expect(find.text('Nessun invito pendente'), findsOneWidget);
    });

    testWidgets('renders a pending invite with accept and decline actions', (
      tester,
    ) async {
      final sessionState = _MutableSessionState(
        invites: [
          _inviteFixture(
            id: 77,
            clubName: 'Club Uno',
            status: ClubInviteStatus.pending,
          ),
        ],
        pendingReceivedInvitesCount: 1,
      );
      final controller = _buildController(sessionState);
      final repository = _FakeClubInvitesRepository(sessionState);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrapWithSession(
          controller,
          ReceivedClubInvitesPage(repository: repository),
        ),
      );
      await _waitForController(controller);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('received-invite-card-77')), findsOneWidget);
      expect(find.text('Club Uno'), findsOneWidget);
      expect(find.text('Accetta'), findsOneWidget);
      expect(find.text('Rifiuta'), findsOneWidget);
      expect(find.text('In attesa'), findsOneWidget);
    });

    testWidgets('accept calls repository and updates the UI', (tester) async {
      final sessionState = _MutableSessionState(
        invites: [
          _inviteFixture(
            id: 77,
            clubName: 'Club Uno',
            status: ClubInviteStatus.pending,
          ),
        ],
        pendingReceivedInvitesCount: 1,
      );
      final controller = _buildController(sessionState);
      final repository = _FakeClubInvitesRepository(sessionState);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrapWithSession(
          controller,
          ReceivedClubInvitesPage(repository: repository),
        ),
      );
      await _waitForController(controller);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('received-invite-accept-77')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('received-invite-accept-confirm')));
      await tester.pumpAndSettle();

      expect(repository.acceptedInviteIds, ['77']);
      expect(controller.hasClubMembership, isTrue);
      expect(
        find.byKey(const Key('received-invites-empty-state')),
        findsOneWidget,
      );
    });

    testWidgets('decline calls repository and updates the UI', (tester) async {
      final sessionState = _MutableSessionState(
        invites: [
          _inviteFixture(
            id: 77,
            clubName: 'Club Uno',
            status: ClubInviteStatus.pending,
          ),
        ],
        pendingReceivedInvitesCount: 1,
      );
      final controller = _buildController(sessionState);
      final repository = _FakeClubInvitesRepository(sessionState);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrapWithSession(
          controller,
          ReceivedClubInvitesPage(repository: repository),
        ),
      );
      await _waitForController(controller);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rifiuta'));
      await tester.pumpAndSettle();

      expect(repository.declinedInviteIds, ['77']);
      expect(controller.hasClubMembership, isFalse);
      expect(
        find.byKey(const Key('received-invites-empty-state')),
        findsOneWidget,
      );
    });

    testWidgets('notification CTA opens the received invites page', (
      tester,
    ) async {
      final sessionState = _MutableSessionState(
        invites: [
          _inviteFixture(
            id: 77,
            clubName: 'Club Uno',
            status: ClubInviteStatus.pending,
          ),
        ],
        notifications: [_notificationFixture(id: 5, inviteId: 77)],
        unreadNotificationsCount: 1,
        pendingReceivedInvitesCount: 1,
      );
      final controller = _buildController(sessionState);
      final notificationsRepository = _FakeNotificationsRepository(
        sessionState,
      );
      final invitesRepository = _FakeClubInvitesRepository(sessionState);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrapWithSession(
          controller,
          NotificationsPage(
            repository: notificationsRepository,
            clubInvitesRepository: invitesRepository,
          ),
        ),
      );
      await _waitForController(controller);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('notification-action-cta-5')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('received-invites-page')), findsOneWidget);
      expect(find.text('Club Uno'), findsOneWidget);
    });

    testWidgets(
      'ClubAccessHubPage shows the invites CTA when pending invites exist',
      (tester) async {
        final sessionState = _MutableSessionState(
          invites: [
            _inviteFixture(
              id: 77,
              clubName: 'Club Uno',
              status: ClubInviteStatus.pending,
            ),
          ],
          pendingReceivedInvitesCount: 2,
        );
        final controller = _buildController(sessionState);
        final invitesRepository = _FakeClubInvitesRepository(sessionState);
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrapWithSession(
            controller,
            ClubAccessHubPage(
              onOpenPlayerSetup: () async {},
              onDeleteAccount: () async {},
              clubInvitesRepository: invitesRepository,
            ),
          ),
        );
        await _waitForController(controller);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('club-access-pending-invites-card')),
          findsOneWidget,
        );
        expect(find.text('Hai 2 inviti ricevuti'), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('club-access-pending-invites-card')),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('received-invites-page')), findsOneWidget);
      },
    );
  });
}

AppSessionController _buildController(_MutableSessionState state) {
  final currentPlayer = state.hasClubMembership
      ? const PlayerProfile(
          id: 7,
          clubId: 1,
          membershipId: 101,
          nome: 'Mario',
          cognome: 'Rossi',
          teamRole: 'player',
        )
      : null;

  return AppSessionController(
    authRepository: _FakeAuthRepository(
      stateBuilder: () => ResolvedSessionState(
        user: const AuthenticatedUser(id: 'user-1', email: 'user@example.com'),
        membership: state.hasClubMembership
            ? const Membership(
                id: 101,
                clubId: 1,
                role: 'player',
                status: 'active',
              )
            : null,
        club: state.hasClubMembership
            ? const Club(id: 1, name: 'Club Uno', slug: 'club-uno')
            : null,
        currentPlayer: currentPlayer,
        vicePermissions: VicePermissions.defaults,
        unreadNotificationsCount: state.unreadNotificationsCount,
        pendingReceivedInvitesCount: state.pendingReceivedInvitesCount,
      ),
    ),
  );
}

ClubInvite _inviteFixture({
  required dynamic id,
  required String clubName,
  required ClubInviteStatus status,
}) {
  return ClubInvite(
    id: id,
    clubId: 1,
    club: Club(id: 1, name: clubName, slug: 'club-uno'),
    createdByUserId: 'captain-1',
    createdByMembershipId: 10,
    targetUserId: 'user-1',
    targetPlayerProfileId: 30,
    targetAccountEmail: 'user@example.com',
    targetNome: 'Mario',
    targetCognome: 'Rossi',
    targetIdConsole: 'mario-7',
    targetPrimaryRole: 'ATT',
    status: status,
    createdAt: DateTime(2026, 5, 5, 12, 0),
  );
}

AppNotification _notificationFixture({
  required dynamic id,
  required dynamic inviteId,
}) {
  return AppNotification(
    id: id,
    recipientUserId: 'user-1',
    clubId: 1,
    notificationType: AppNotificationType.clubInviteReceived,
    title: 'Invito ricevuto',
    body: 'Hai ricevuto un invito nel club.',
    metadata: {
      'redirect': {'path': '/invites/$inviteId'},
      'inviteId': inviteId,
    },
    relatedInviteId: inviteId,
    readAt: null,
    createdAt: DateTime(2026, 5, 5, 12, 0),
  );
}

Widget _wrapWithSession(AppSessionController controller, Widget child) {
  return AppSessionScope(
    controller: controller,
    child: MaterialApp(home: child),
  );
}

class _MutableSessionState {
  _MutableSessionState({
    List<ClubInvite>? invites,
    List<AppNotification>? notifications,
    this.pendingReceivedInvitesCount = 0,
    this.unreadNotificationsCount = 0,
  }) : invites = List<ClubInvite>.from(invites ?? const []),
       notifications = List<AppNotification>.from(notifications ?? const []);

  List<ClubInvite> invites;
  List<AppNotification> notifications;
  bool hasClubMembership = false;
  int pendingReceivedInvitesCount;
  int unreadNotificationsCount;
}

class _FakeClubInvitesRepository extends ClubInvitesRepository {
  _FakeClubInvitesRepository(this.state);

  final _MutableSessionState state;
  final List<String> acceptedInviteIds = <String>[];
  final List<String> declinedInviteIds = <String>[];

  @override
  Future<ClubInviteListResult> getReceivedInvites({
    ClubInviteListStatus status = ClubInviteListStatus.pending,
    int limit = 20,
    int? cursor,
  }) async {
    final filteredInvites = status == ClubInviteListStatus.pending
        ? state.invites
              .where((invite) => invite.isPending)
              .toList(growable: false)
        : List<ClubInvite>.from(state.invites);

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
  Future<ClubInviteAcceptResult> acceptInvite(dynamic inviteId) async {
    acceptedInviteIds.add('$inviteId');
    final index = state.invites.indexWhere(
      (invite) => '${invite.id}' == '$inviteId',
    );
    final updatedInvite = state.invites[index].copyWith(
      status: ClubInviteStatus.accepted,
      resolvedAt: DateTime(2026, 5, 5, 12, 30),
      acceptedMembershipId: 101,
      acceptedPlayerId: 7,
    );
    state.invites[index] = updatedInvite;
    state.hasClubMembership = true;
    state.pendingReceivedInvitesCount = state.invites
        .where((invite) => invite.isPending)
        .length;

    return ClubInviteAcceptResult(
      invite: updatedInvite,
      membership: const Membership(
        id: 101,
        clubId: 1,
        role: 'player',
        status: 'active',
      ),
      player: const PlayerProfile(
        id: 7,
        clubId: 1,
        membershipId: 101,
        nome: 'Mario',
        cognome: 'Rossi',
        teamRole: 'player',
      ),
    );
  }

  @override
  Future<ClubInvite> declineInvite(dynamic inviteId) async {
    declinedInviteIds.add('$inviteId');
    final index = state.invites.indexWhere(
      (invite) => '${invite.id}' == '$inviteId',
    );
    final updatedInvite = state.invites[index].copyWith(
      status: ClubInviteStatus.declined,
      resolvedAt: DateTime(2026, 5, 5, 12, 30),
    );
    state.invites[index] = updatedInvite;
    state.pendingReceivedInvitesCount = state.invites
        .where((invite) => invite.isPending)
        .length;
    return updatedInvite;
  }
}

class _FakeNotificationsRepository extends NotificationsRepository {
  _FakeNotificationsRepository(this.state);

  final _MutableSessionState state;

  @override
  Future<AppNotificationsListResult> getNotifications({
    NotificationsFilter filter = NotificationsFilter.all,
    int limit = 20,
    int? cursor,
  }) async {
    final source = filter == NotificationsFilter.unread
        ? state.notifications.where((notification) => notification.isUnread)
        : state.notifications;

    return AppNotificationsListResult(
      notifications: source.toList(growable: false),
      unreadCount: state.unreadNotificationsCount,
      pagination: CursorPagination(
        limit: limit,
        hasMore: false,
        nextCursor: null,
      ),
    );
  }

  @override
  Future<MarkNotificationReadResult> markAsRead(dynamic notificationId) async {
    final index = state.notifications.indexWhere(
      (notification) => '${notification.id}' == '$notificationId',
    );
    final updatedNotification = state.notifications[index].copyWith(
      readAt: DateTime(2026, 5, 5, 12, 45),
    );
    state.notifications[index] = updatedNotification;
    state.unreadNotificationsCount = state.notifications
        .where((notification) => notification.isUnread)
        .length;

    return MarkNotificationReadResult(
      notification: updatedNotification,
      unreadCount: state.unreadNotificationsCount,
    );
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
