import 'package:clubline/core/app_session.dart';
import 'package:clubline/data/auth_repository.dart';
import 'package:clubline/data/notifications_repository.dart';
import 'package:clubline/models/app_notification.dart';
import 'package:clubline/models/authenticated_user.dart';
import 'package:clubline/models/club.dart';
import 'package:clubline/models/cursor_pagination.dart';
import 'package:clubline/models/membership.dart';
import 'package:clubline/models/player_profile.dart';
import 'package:clubline/models/resolved_session_state.dart';
import 'package:clubline/models/vice_permissions.dart';
import 'package:clubline/ui/pages/home_page.dart';
import 'package:clubline/ui/pages/lineups_page.dart';
import 'package:clubline/ui/pages/notifications_page.dart';
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

  group('Notifications UI', () {
    testWidgets(
      'badge is visible on HomePage when unread count is greater than zero',
      (tester) async {
        final state = _NotificationsStateFixture(
          notifications: [
            _notificationFixture(id: 1, readAt: null),
            _notificationFixture(id: 2, readAt: null),
          ],
        );
        final controller = _buildController(state, withClub: true);
        addTearDown(controller.dispose);

        await tester.pumpWidget(_wrapWithSession(controller, _buildHomePage()));
        await _waitForController(controller);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('notifications-bell-button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('notifications-bell-badge')),
          findsOneWidget,
        );
        expect(find.text('2'), findsOneWidget);
      },
    );

    testWidgets('badge is hidden when unread count is zero', (tester) async {
      final state = _NotificationsStateFixture(notifications: const []);
      final controller = _buildController(state, withClub: true);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrapWithSession(controller, _buildHomePage()));
      await _waitForController(controller);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('notifications-bell-button')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('notifications-bell-badge')), findsNothing);
    });

    testWidgets('inbox shows empty state when there are no notifications', (
      tester,
    ) async {
      final state = _NotificationsStateFixture(notifications: const []);
      final controller = _buildController(state);
      final repository = _FakeNotificationsRepository(state);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrapWithSession(controller, NotificationsPage(repository: repository)),
      );
      await _waitForController(controller);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('notifications-empty-state')),
        findsOneWidget,
      );
      expect(find.text('Nessuna notifica disponibile'), findsOneWidget);
    });

    testWidgets('mark all read updates the inbox UI', (tester) async {
      final state = _NotificationsStateFixture(
        notifications: [
          _notificationFixture(id: 1, readAt: null),
          _notificationFixture(
            id: 2,
            readAt: DateTime(2026, 5, 5, 11, 30),
            title: 'Notifica già letta',
          ),
        ],
      );
      final controller = _buildController(state);
      final repository = _FakeNotificationsRepository(state);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrapWithSession(controller, NotificationsPage(repository: repository)),
      );
      await _waitForController(controller);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('notification-unread-badge-1')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('notifications-mark-all-button')));
      await tester.pumpAndSettle();

      expect(repository.markAllReadCalls, 1);
      expect(
        find.byKey(const Key('notification-unread-badge-1')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('notification-read-badge-1')),
        findsOneWidget,
      );
      expect(controller.unreadNotificationsCount, 0);
    });

    testWidgets('inbox renders unread and read states distinctly', (
      tester,
    ) async {
      final state = _NotificationsStateFixture(
        notifications: [
          _notificationFixture(id: 1, readAt: null),
          _notificationFixture(
            id: 2,
            readAt: DateTime(2026, 5, 5, 11, 30),
            title: 'Notifica già letta',
          ),
        ],
      );
      final controller = _buildController(state);
      final repository = _FakeNotificationsRepository(state);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrapWithSession(controller, NotificationsPage(repository: repository)),
      );
      await _waitForController(controller);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('notification-unread-badge-1')),
        findsOneWidget,
      );
      expect(find.text('Invito ricevuto'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Notifica già letta'),
        240,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
      expect(find.text('Notifica già letta'), findsOneWidget);
      expect(
        find.byKey(const Key('notification-read-badge-2')),
        findsOneWidget,
      );
    });

    testWidgets('inbox renders lineup and attendance notifications', (
      tester,
    ) async {
      final state = _NotificationsStateFixture(
        notifications: [
          _notificationFixture(
            id: 11,
            readAt: null,
            notificationType: AppNotificationType.lineupPublished,
            title: 'Formazione pubblicata',
            body: 'La nuova formazione è disponibile.',
            metadata: const {
              'redirect': {'path': '/lineups'},
            },
          ),
          _notificationFixture(
            id: 12,
            readAt: DateTime(2026, 5, 5, 11, 30),
            notificationType: AppNotificationType.attendancePublished,
            title: 'Presenze pubblicate',
            body: 'Il nuovo sondaggio presenze è disponibile.',
            metadata: const {
              'redirect': {'path': '/attendance'},
            },
          ),
        ],
      );
      final controller = _buildController(state, withClub: true);
      final repository = _FakeNotificationsRepository(state);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrapWithSession(controller, NotificationsPage(repository: repository)),
      );
      await _waitForController(controller);
      await tester.pumpAndSettle();

      expect(find.text('Formazione'), findsOneWidget);
      expect(find.text('Apri formazioni'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Presenze pubblicate'),
        240,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
      expect(find.text('Presenze'), findsOneWidget);
      expect(find.text('Apri presenze'), findsOneWidget);
    });

    testWidgets('tap on lineup notification opens the lineups page', (
      tester,
    ) async {
      final state = _NotificationsStateFixture(
        notifications: [
          _notificationFixture(
            id: 21,
            readAt: null,
            notificationType: AppNotificationType.lineupPublished,
            title: 'Formazione pubblicata',
            metadata: const {
              'redirect': {'path': '/lineups'},
            },
          ),
        ],
      );
      final controller = _buildController(state, withClub: true);
      final repository = _FakeNotificationsRepository(state);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrapWithSession(controller, NotificationsPage(repository: repository)),
      );
      await _waitForController(controller);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('notification-action-cta-21')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(LineupsPage), findsOneWidget);
    });

    testWidgets(
      'tap on attendance notification shows a safe fallback message',
      (tester) async {
      final state = _NotificationsStateFixture(
        notifications: [
          _notificationFixture(
            id: 22,
            readAt: null,
            notificationType: AppNotificationType.attendancePublished,
            title: 'Presenze pubblicate',
            metadata: const {
              'redirect': {'path': '/attendance'},
            },
          ),
        ],
      );
      final controller = _buildController(state, withClub: true);
      final repository = _FakeNotificationsRepository(state);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrapWithSession(controller, NotificationsPage(repository: repository)),
      );
      await _waitForController(controller);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('notification-action-cta-22')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text(
          'Apri la sezione Presenze dalla home del club per vedere il nuovo sondaggio.',
        ),
        findsOneWidget,
      );
    });
  });
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
    onOpenVicePermissionsSettings: () {},
    onOpenClubInfoSettings: () {},
    onDeleteAccount: () async {},
  );
}

Widget _wrapWithSession(AppSessionController controller, Widget child) {
  return AppSessionScope(
    controller: controller,
    child: MaterialApp(home: child),
  );
}

AppSessionController _buildController(
  _NotificationsStateFixture state, {
  bool withClub = false,
}) {
  final currentPlayer = withClub
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
        membership: withClub
            ? const Membership(
                id: 101,
                clubId: 1,
                role: 'player',
                status: 'active',
              )
            : null,
        club: withClub
            ? const Club(id: 1, name: 'Clubline', slug: 'clubline')
            : null,
        currentPlayer: currentPlayer,
        vicePermissions: VicePermissions.defaults,
        unreadNotificationsCount: state.unreadCount,
        pendingReceivedInvitesCount: 0,
      ),
    ),
  );
}

AppNotification _notificationFixture({
  required dynamic id,
  required DateTime? readAt,
  AppNotificationType notificationType = AppNotificationType.clubInviteReceived,
  String title = 'Invito ricevuto',
  String? body = 'Hai ricevuto un nuovo invito nel club.',
  Map<String, dynamic> metadata = const {
    'redirect': {'path': '/invites/1'},
  },
}) {
  return AppNotification(
    id: id,
    recipientUserId: 'user-1',
    clubId: 1,
    notificationType: notificationType,
    title: title,
    body: body,
    metadata: metadata,
    relatedInviteId: 1,
    readAt: readAt,
    createdAt: DateTime(2026, 5, 5, 12, 0),
  );
}

class _NotificationsStateFixture {
  _NotificationsStateFixture({required List<AppNotification> notifications})
    : _notifications = List<AppNotification>.from(notifications);

  List<AppNotification> _notifications;

  List<AppNotification> listNotifications(NotificationsFilter filter) {
    final source = filter == NotificationsFilter.unread
        ? _notifications.where((notification) => notification.isUnread)
        : _notifications;
    return source.toList(growable: false);
  }

  int get unreadCount =>
      _notifications.where((notification) => notification.isUnread).length;

  AppNotification markRead(dynamic notificationId) {
    final index = _notifications.indexWhere(
      (notification) => '${notification.id}' == '$notificationId',
    );
    final updatedNotification = _notifications[index].copyWith(
      readAt: DateTime(2026, 5, 5, 12, 45),
    );
    _notifications[index] = updatedNotification;
    return updatedNotification;
  }

  void markAllRead() {
    _notifications = _notifications
        .map(
          (notification) => notification.isUnread
              ? notification.copyWith(readAt: DateTime(2026, 5, 5, 12, 45))
              : notification,
        )
        .toList(growable: false);
  }
}

class _FakeNotificationsRepository extends NotificationsRepository {
  _FakeNotificationsRepository(this.state);

  final _NotificationsStateFixture state;
  int markAllReadCalls = 0;

  @override
  Future<AppNotificationsListResult> getNotifications({
    NotificationsFilter filter = NotificationsFilter.all,
    int limit = 20,
    int? cursor,
  }) async {
    return AppNotificationsListResult(
      notifications: state.listNotifications(filter),
      unreadCount: state.unreadCount,
      pagination: CursorPagination(
        limit: limit,
        hasMore: false,
        nextCursor: null,
      ),
    );
  }

  @override
  Future<MarkNotificationReadResult> markAsRead(dynamic notificationId) async {
    final notification = state.markRead(notificationId);
    return MarkNotificationReadResult(
      notification: notification,
      unreadCount: state.unreadCount,
    );
  }

  @override
  Future<int> markAllAsRead() async {
    markAllReadCalls += 1;
    state.markAllRead();
    return state.unreadCount;
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
