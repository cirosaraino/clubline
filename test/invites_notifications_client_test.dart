import 'dart:convert';

import 'package:clubline/core/app_data_sync.dart';
import 'package:clubline/core/app_session.dart';
import 'package:clubline/data/api_client.dart';
import 'package:clubline/data/auth_repository.dart';
import 'package:clubline/data/auth_session_store.dart';
import 'package:clubline/data/club_invites_repository.dart';
import 'package:clubline/data/notifications_repository.dart';
import 'package:clubline/models/app_notification.dart';
import 'package:clubline/models/auth_session.dart';
import 'package:clubline/models/authenticated_user.dart';
import 'package:clubline/models/club_invite.dart';
import 'package:clubline/models/invite_candidate.dart';
import 'package:clubline/models/membership.dart';
import 'package:clubline/models/player_profile.dart';
import 'package:clubline/models/resolved_session_state.dart';
import 'package:clubline/models/vice_permissions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _waitForController(AppSessionController controller) async {
  while (controller.isSessionGateResolving || controller.isLoading) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<void> _waitForCondition(bool Function() predicate) async {
  for (var attempt = 0; attempt < 50; attempt += 1) {
    if (predicate()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }

  fail('Condition not reached in time.');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('invites and notifications models', () {
    test('parse ClubInvite, AppNotification and InviteCandidate payloads', () {
      final invite = ClubInvite.fromMap({
        'id': 12,
        'club_id': 4,
        'target_user_id': 'user-1',
        'target_nome': 'Mario',
        'target_cognome': 'Rossi',
        'target_account_email': 'mario@example.com',
        'target_id_console': 'mario-7',
        'target_primary_role': 'CDC',
        'status': 'pending',
        'created_at': '2026-05-04T10:00:00.000Z',
      });
      final notification = AppNotification.fromMap({
        'id': 91,
        'recipient_user_id': 'user-1',
        'club_id': 4,
        'notification_type': 'club_invite_received',
        'title': 'Invito ricevuto',
        'body': 'Hai un nuovo invito',
        'metadata': {
          'redirect': {'path': '/invites/12'},
        },
        'related_invite_id': 12,
        'read_at': null,
        'created_at': '2026-05-04T10:05:00.000Z',
      });
      final candidate = InviteCandidate.fromMap({
        'user_id': 'user-2',
        'player_profile_id': 33,
        'nome': 'Luigi',
        'cognome': 'Verdi',
        'account_email': 'luigi@example.com',
        'id_console': 'luigi-10',
        'primary_role': 'ATT',
        'invitable': false,
        'reason': 'pending_join_request_other_club',
      });

      expect(invite.status, ClubInviteStatus.pending);
      expect(invite.fullName, 'Mario Rossi');
      expect(
        notification.notificationType,
        AppNotificationType.clubInviteReceived,
      );
      expect(notification.isUnread, isTrue);
      expect(notification.metadata['redirect'], isA<Map>());
      expect(
        candidate.reason,
        InviteCandidateReason.pendingJoinRequestOtherClub,
      );
      expect(candidate.invitable, isFalse);
    });

    test('ResolvedSessionState parses counts and vice_manage_invites', () {
      final state = ResolvedSessionState.fromMap({
        'user': {'id': 'user-1', 'email': 'captain@example.com'},
        'vicePermissions': {
          'vice_manage_players': false,
          'vice_manage_lineups': true,
          'vice_manage_streams': false,
          'vice_manage_attendance': false,
          'vice_manage_invites': true,
          'vice_manage_team_info': false,
        },
        'unreadNotificationsCount': 3,
        'pendingReceivedInvitesCount': 1,
      });

      expect(state.unreadNotificationsCount, 3);
      expect(state.pendingReceivedInvitesCount, 1);
      expect(state.hasUnreadNotifications, isTrue);
      expect(state.hasPendingReceivedInvites, isTrue);
      expect(state.vicePermissions.manageInvites, isTrue);
    });

    test('parseAppDataScope maps invites and notifications', () {
      expect(parseAppDataScope('invites'), AppDataScope.invites);
      expect(parseAppDataScope('notifications'), AppDataScope.notifications);
      expect(parseAppDataScope('teamInfo'), AppDataScope.clubInfo);
      expect(parseAppDataScope('unknown'), isNull);
    });
  });

  group('client repositories', () {
    test(
      'ClubInvitesRepository searches candidates and parses list results',
      () async {
        final requests = <http.Request>[];
        final apiClient = ApiClient(
          httpClient: MockClient((request) async {
            requests.add(request);

            if (request.url.path.endsWith('/club-invites/candidates')) {
              return http.Response(
                jsonEncode({
                  'candidates': [
                    {
                      'user_id': 'user-2',
                      'player_profile_id': 45,
                      'nome': 'Luigi',
                      'cognome': 'Verdi',
                      'account_email': 'luigi@example.com',
                      'id_console': 'luigi-10',
                      'primary_role': 'ATT',
                      'invitable': true,
                      'reason': null,
                    },
                  ],
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }

            return http.Response(
              jsonEncode({
                'invites': [
                  {
                    'id': 8,
                    'club_id': 3,
                    'target_user_id': 'user-2',
                    'target_nome': 'Luigi',
                    'target_cognome': 'Verdi',
                    'status': 'pending',
                    'created_at': '2026-05-04T10:00:00.000Z',
                  },
                ],
                'pagination': {
                  'limit': 10,
                  'hasMore': false,
                  'nextCursor': null,
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
          sessionStore: _FakeAuthSessionStore(),
        );
        final repository = ClubInvitesRepository(apiClient: apiClient);

        final candidates = await repository.searchCandidates(
          'luigi',
          limit: 10,
        );
        final sentInvites = await repository.getSentInvites(limit: 10);

        expect(candidates, hasLength(1));
        expect(candidates.single.fullName, 'Luigi Verdi');
        expect(sentInvites.invites, hasLength(1));
        expect(sentInvites.invites.single.status, ClubInviteStatus.pending);
        expect(sentInvites.pagination.limit, 10);
        expect(requests.first.url.queryParameters, containsPair('q', 'luigi'));
        expect(requests.first.headers['authorization'], 'Bearer access-token');
        expect(requests.last.url.path, '/api/club-invites/sent');
      },
    );

    test(
      'ClubInvitesRepository create/accept/revoke/decline use backend payloads',
      () async {
        final requestPaths = <String>[];
        final apiClient = ApiClient(
          httpClient: MockClient((request) async {
            requestPaths.add(request.url.path);

            final payload = switch (request.url.path) {
              '/api/club-invites' => {
                'invite': {
                  'id': 50,
                  'club_id': 3,
                  'target_user_id': 'user-9',
                  'target_nome': 'Mario',
                  'target_cognome': 'Rossi',
                  'status': 'pending',
                },
              },
              '/api/club-invites/50/accept' => {
                'invite': {
                  'id': 50,
                  'club_id': 3,
                  'target_user_id': 'user-9',
                  'target_nome': 'Mario',
                  'target_cognome': 'Rossi',
                  'status': 'accepted',
                },
                'membership': {
                  'id': 10,
                  'club_id': 3,
                  'role': 'player',
                  'status': 'active',
                },
                'player': {
                  'id': 200,
                  'club_id': 3,
                  'membership_id': 10,
                  'nome': 'Mario',
                  'cognome': 'Rossi',
                  'team_role': 'player',
                },
              },
              '/api/club-invites/50/revoke' => {
                'invite': {
                  'id': 50,
                  'club_id': 3,
                  'target_user_id': 'user-9',
                  'target_nome': 'Mario',
                  'target_cognome': 'Rossi',
                  'status': 'revoked',
                },
              },
              '/api/club-invites/50/decline' => {
                'invite': {
                  'id': 50,
                  'club_id': 3,
                  'target_user_id': 'user-9',
                  'target_nome': 'Mario',
                  'target_cognome': 'Rossi',
                  'status': 'declined',
                },
              },
              _ => <String, dynamic>{},
            };

            return http.Response(
              jsonEncode(payload),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
          sessionStore: _FakeAuthSessionStore(),
        );
        final repository = ClubInvitesRepository(apiClient: apiClient);

        final createdInvite = await repository.createInvite('user-9');
        final acceptedInvite = await repository.acceptInvite(50);
        final revokedInvite = await repository.revokeInvite(50);
        final declinedInvite = await repository.declineInvite(50);

        expect(createdInvite.status, ClubInviteStatus.pending);
        expect(acceptedInvite.invite.status, ClubInviteStatus.accepted);
        expect(acceptedInvite.membership, isA<Membership>());
        expect(acceptedInvite.player.fullName, 'Mario Rossi');
        expect(revokedInvite.status, ClubInviteStatus.revoked);
        expect(declinedInvite.status, ClubInviteStatus.declined);
        expect(
          requestPaths,
          containsAll([
            '/api/club-invites',
            '/api/club-invites/50/accept',
            '/api/club-invites/50/revoke',
            '/api/club-invites/50/decline',
          ]),
        );
      },
    );

    test(
      'NotificationsRepository parses unread counts and read actions',
      () async {
        final requestPaths = <String>[];
        final apiClient = ApiClient(
          httpClient: MockClient((request) async {
            requestPaths.add(request.url.path);

            final payload = switch (request.url.path) {
              '/api/notifications' => {
                'notifications': [
                  {
                    'id': 91,
                    'recipient_user_id': 'user-1',
                    'club_id': 4,
                    'notification_type': 'club_invite_received',
                    'title': 'Invito ricevuto',
                    'body': 'Hai un invito',
                    'metadata': {
                      'redirect': {'path': '/invites/50'},
                    },
                    'related_invite_id': 50,
                    'read_at': null,
                    'created_at': '2026-05-04T10:05:00.000Z',
                  },
                ],
                'unreadCount': 1,
                'pagination': {
                  'limit': 20,
                  'hasMore': false,
                  'nextCursor': null,
                },
              },
              '/api/notifications/91/read' => {
                'success': true,
                'notification': {
                  'id': 91,
                  'recipient_user_id': 'user-1',
                  'club_id': 4,
                  'notification_type': 'club_invite_received',
                  'title': 'Invito ricevuto',
                  'body': 'Hai un invito',
                  'metadata': {
                    'redirect': {'path': '/invites/50'},
                  },
                  'related_invite_id': 50,
                  'read_at': '2026-05-04T10:10:00.000Z',
                  'created_at': '2026-05-04T10:05:00.000Z',
                },
                'unreadCount': 0,
              },
              '/api/notifications/read-all' => {
                'success': true,
                'unreadCount': 0,
              },
              _ => <String, dynamic>{},
            };

            return http.Response(
              jsonEncode(payload),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
          sessionStore: _FakeAuthSessionStore(),
        );
        final repository = NotificationsRepository(apiClient: apiClient);

        final listResult = await repository.getNotifications(
          filter: NotificationsFilter.unread,
        );
        final readResult = await repository.markAsRead(91);
        final unreadCount = await repository.markAllAsRead();

        expect(listResult.unreadCount, 1);
        expect(listResult.notifications.single.isUnread, isTrue);
        expect(readResult.notification.isUnread, isFalse);
        expect(readResult.unreadCount, 0);
        expect(unreadCount, 0);
        expect(
          requestPaths,
          containsAll([
            '/api/notifications',
            '/api/notifications/91/read',
            '/api/notifications/read-all',
          ]),
        );
      },
    );
  });

  group('session and realtime integration', () {
    test(
      'AppSessionController exposes counts, enables realtime for authenticated users and refreshes on notifications/invites scopes',
      () async {
        var unreadCount = 2;
        var pendingInvitesCount = 1;
        final authRepository = _FakeAuthRepository(
          stateBuilder: () => ResolvedSessionState(
            user: const AuthenticatedUser(
              id: 'user-1',
              email: 'user@example.com',
            ),
            vicePermissions: const VicePermissions(manageInvites: true),
            unreadNotificationsCount: unreadCount,
            pendingReceivedInvitesCount: pendingInvitesCount,
          ),
        );

        final controller = AppSessionController(authRepository: authRepository);
        addTearDown(controller.dispose);

        await _waitForController(controller);

        expect(controller.unreadNotificationsCount, 2);
        expect(controller.pendingReceivedInvitesCount, 1);
        expect(controller.hasUnreadNotifications, isTrue);
        expect(controller.hasPendingReceivedInvites, isTrue);
        expect(controller.shouldEnableRealtime, isTrue);

        unreadCount = 0;
        pendingInvitesCount = 0;
        AppDataSync.instance.notifyDataChanged({
          AppDataScope.notifications,
          AppDataScope.invites,
        }, reason: 'test_refresh');

        await _waitForCondition(() => authRepository.resolveCalls >= 2);

        expect(controller.unreadNotificationsCount, 0);
        expect(controller.pendingReceivedInvitesCount, 0);
        expect(controller.hasUnreadNotifications, isFalse);
        expect(controller.hasPendingReceivedInvites, isFalse);
      },
    );
  });
}

class _FakeAuthSessionStore extends AuthSessionStore {
  @override
  Future<AuthSession?> readSession() async {
    return AuthSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      user: const AuthenticatedUser(id: 'user-1', email: 'user@example.com'),
    );
  }
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({required this.stateBuilder});

  final ResolvedSessionState Function() stateBuilder;
  int resolveCalls = 0;

  @override
  Future<void> warmUpBackend() async {}

  @override
  Future<ResolvedSessionState?> resolveSessionState() async {
    resolveCalls += 1;
    return stateBuilder();
  }
}
