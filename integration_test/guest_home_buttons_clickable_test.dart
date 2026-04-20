import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:clubline/app.dart';
import 'package:web/web.dart' as web;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> setStandaloneSimulation(bool enabled) async {
    try {
      if (enabled) {
        web.window.localStorage.setItem('e2e_force_standalone', '1');
      } else {
        web.window.localStorage.removeItem('e2e_force_standalone');
      }
    } catch (_) {}
  }

  Future<void> assertGuestButtonsAreClickable(WidgetTester tester) async {
    await tester.pumpWidget(const SquadraApp());

    await tester.pump(const Duration(milliseconds: 250));

    final signInButton = find.byKey(const Key('home-guest-sign-in-button'));
    final signUpButton = find.byKey(const Key('home-guest-sign-up-button'));

    expect(signInButton, findsOneWidget);
    expect(signUpButton, findsOneWidget);

    await tester.tap(signInButton);
    await tester.pumpAndSettle(const Duration(seconds: 3));
    final signInSheetTitle = find.text('Accedi alla squadra');
    expect(signInSheetTitle, findsOneWidget);

    Navigator.of(tester.element(signInSheetTitle)).pop();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(signUpButton);
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('Registrati nella squadra'), findsOneWidget);
  }

  setUp(() async {
    await setStandaloneSimulation(false);
  });

  tearDown(() async {
    await setStandaloneSimulation(false);
  });

  testWidgets('guest-home-buttons-clickable-browser', (tester) async {
    await assertGuestButtonsAreClickable(tester);
  });

  testWidgets('guest-home-buttons-clickable-standalone-simulated', (
    tester,
  ) async {
    await setStandaloneSimulation(true);
    await assertGuestButtonsAreClickable(tester);
  });
}
