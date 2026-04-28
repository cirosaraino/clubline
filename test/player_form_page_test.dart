import 'package:clubline/core/app_session.dart';
import 'package:clubline/data/auth_repository.dart';
import 'package:clubline/data/player_repository.dart';
import 'package:clubline/data/profile_setup_draft_store.dart';
import 'package:clubline/models/authenticated_user.dart';
import 'package:clubline/models/club.dart';
import 'package:clubline/models/membership.dart';
import 'package:clubline/models/player_profile.dart';
import 'package:clubline/models/resolved_session_state.dart';
import 'package:clubline/models/vice_permissions.dart';
import 'package:clubline/ui/pages/player_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PlayerFormPage', () {
    testWidgets(
      'restores shirt number and roles from the saved draft in draft-only edit flow',
      (tester) async {
        await ProfileSetupDraftStore.instance.save(
          const ProfileSetupDraft(
            nome: 'Mario',
            cognome: 'Rossi',
            idConsole: 'mario-7',
            shirtNumber: 10,
            primaryRole: 'CDC',
            secondaryRoles: ['CC', 'TS'],
            accountEmail: 'draft@example.com',
          ),
        );

        final controller = _buildSessionController(email: 'draft@example.com');
        addTearDown(controller.dispose);

        await _pumpPlayerForm(
          tester,
          controller: controller,
          child: const PlayerFormPage(draftOnly: true),
        );

        expect(find.text('Mario'), findsOneWidget);
        expect(find.text('Rossi'), findsOneWidget);
        expect(find.text('mario-7'), findsOneWidget);
        expect(find.byKey(const ValueKey('shirt-number-10')), findsOneWidget);
        expect(find.byKey(const ValueKey('primary-role-CDC')), findsOneWidget);
        expect(
          tester
              .widget<FilterChip>(
                find.widgetWithText(FilterChip, 'CC - Centrocampista'),
              )
              .selected,
          isTrue,
        );
        expect(
          tester
              .widget<FilterChip>(
                find.widgetWithText(FilterChip, 'TS - Difensore'),
              )
              .selected,
          isTrue,
        );
      },
    );

    testWidgets(
      'prefills existing sports fields and preserves them when saving unchanged',
      (tester) async {
        final existingPlayer = _playerFixture();
        final repository = _FakePlayerRepository(
          existingPlayer: existingPlayer,
        );
        final controller = _buildSessionController(
          email: 'mario@example.com',
          currentPlayerBuilder: () => existingPlayer,
        );
        addTearDown(controller.dispose);

        await _pumpPlayerForm(
          tester,
          controller: controller,
          child: PlayerFormPage(player: existingPlayer, repository: repository),
        );

        expect(find.text('Mario'), findsOneWidget);
        expect(find.text('Rossi'), findsOneWidget);
        expect(find.text('mario-7'), findsOneWidget);
        expect(find.byKey(const ValueKey('shirt-number-11')), findsOneWidget);
        expect(find.byKey(const ValueKey('primary-role-CDC')), findsOneWidget);
        expect(
          tester
              .widget<FilterChip>(
                find.widgetWithText(FilterChip, 'CC - Centrocampista'),
              )
              .selected,
          isTrue,
        );

        await tester.tap(find.text('Salva modifiche'));
        await tester.pumpAndSettle();

        expect(repository.updatedPlayers, hasLength(1));
        final updatedPlayer = repository.updatedPlayers.single;
        expect(updatedPlayer.nome, 'Mario');
        expect(updatedPlayer.cognome, 'Rossi');
        expect(updatedPlayer.accountEmail, 'mario@example.com');
        expect(updatedPlayer.idConsole, 'mario-7');
        expect(updatedPlayer.shirtNumber, 11);
        expect(updatedPlayer.primaryRole, 'CDC');
        expect(updatedPlayer.secondaryRoles, ['CC']);
        expect(updatedPlayer.teamRole, 'player');
      },
    );

    testWidgets('changing one field leaves shirt number and roles untouched', (
      tester,
    ) async {
      final existingPlayer = _playerFixture();
      final repository = _FakePlayerRepository(existingPlayer: existingPlayer);
      final controller = _buildSessionController(
        email: 'mario@example.com',
        currentPlayerBuilder: () => existingPlayer,
      );
      addTearDown(controller.dispose);

      await _pumpPlayerForm(
        tester,
        controller: controller,
        child: PlayerFormPage(player: existingPlayer, repository: repository),
      );

      await tester.enterText(_textFieldByLabel('Cognome'), 'Bianchi');
      await tester.tap(find.text('Salva modifiche'));
      await tester.pumpAndSettle();

      expect(repository.updatedPlayers, hasLength(1));
      final updatedPlayer = repository.updatedPlayers.single;
      expect(updatedPlayer.nome, 'Mario');
      expect(updatedPlayer.cognome, 'Bianchi');
      expect(updatedPlayer.accountEmail, 'mario@example.com');
      expect(updatedPlayer.idConsole, 'mario-7');
      expect(updatedPlayer.shirtNumber, 11);
      expect(updatedPlayer.primaryRole, 'CDC');
      expect(updatedPlayer.secondaryRoles, ['CC']);
      expect(updatedPlayer.teamRole, 'player');
    });
  });
}

Finder _textFieldByLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
}

PlayerProfile _playerFixture({
  String cognome = 'Rossi',
  int shirtNumber = 11,
  String primaryRole = 'CDC',
  List<String> secondaryRoles = const ['CC'],
}) {
  return PlayerProfile(
    id: 7,
    clubId: 1,
    membershipId: 101,
    nome: 'Mario',
    cognome: cognome,
    authUserId: 'auth-1',
    accountEmail: 'mario@example.com',
    shirtNumber: shirtNumber,
    primaryRole: primaryRole,
    secondaryRoles: secondaryRoles,
    idConsole: 'mario-7',
    teamRole: 'player',
  );
}

AppSessionController _buildSessionController({
  required String email,
  PlayerProfile? Function()? currentPlayerBuilder,
}) {
  final playerRepository = _FakePlayerRepository(
    existingPlayer: currentPlayerBuilder?.call(),
  );

  return AppSessionController(
    authRepository: _FakeAuthRepository(
      stateBuilder: () {
        final currentPlayer = currentPlayerBuilder?.call();
        final hasClubMembership = currentPlayer != null;

        return ResolvedSessionState(
          user: AuthenticatedUser(id: 'auth-1', email: email),
          membership: hasClubMembership
              ? const Membership(
                  id: 101,
                  clubId: 1,
                  role: 'player',
                  status: 'active',
                )
              : null,
          club: hasClubMembership
              ? const Club(id: 1, name: 'Clubline', slug: 'clubline')
              : null,
          currentPlayer: currentPlayer,
          vicePermissions: VicePermissions.defaults,
        );
      },
    ),
    playerRepository: playerRepository,
  );
}

Future<void> _pumpPlayerForm(
  WidgetTester tester, {
  required AppSessionController controller,
  required Widget child,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AppSessionScope(
        controller: controller,
        child: const SizedBox.shrink(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.pumpWidget(
    MaterialApp(
      home: AppSessionScope(controller: controller, child: child),
    ),
  );
  await tester.pumpAndSettle();
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
  _FakePlayerRepository({this.existingPlayer});

  PlayerProfile? existingPlayer;
  final List<PlayerProfile> createdPlayers = [];
  final List<PlayerProfile> claimedPlayers = [];
  final List<PlayerProfile> updatedPlayers = [];

  @override
  Future<List<PlayerProfile>> fetchPlayers() async {
    final player = existingPlayer;
    if (player == null) {
      return const [];
    }

    return [player];
  }

  @override
  Future<PlayerProfile> createPlayer(PlayerProfile player) async {
    createdPlayers.add(player);
    existingPlayer = player;
    return player;
  }

  @override
  Future<PlayerProfile> claimPlayer(PlayerProfile player) async {
    claimedPlayers.add(player);
    existingPlayer = player;
    return player;
  }

  @override
  Future<void> updatePlayer(PlayerProfile player) async {
    updatedPlayers.add(player);
    existingPlayer = player;
  }

  @override
  Future<PlayerProfile?> findPlayerByConsoleId(String consoleId) async {
    final player = existingPlayer;
    if (player == null || player.idConsole != consoleId) {
      return null;
    }

    return player;
  }
}
