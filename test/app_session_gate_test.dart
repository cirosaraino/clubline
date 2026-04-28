import 'package:clubline/core/app_session_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveAppSessionGate', () {
    test('returns resolving while the session gate is still running', () {
      expect(
        resolveAppSessionGate(
          isResolving: true,
          hasResolutionError: false,
          isAuthenticated: true,
          hasClubMembership: true,
          hasPlayerIdentityDraft: true,
          hasCurrentPlayer: true,
          needsCurrentPlayerCompletion: false,
        ),
        AppSessionGateKind.resolving,
      );
    });

    test('returns error when resolution failed', () {
      expect(
        resolveAppSessionGate(
          isResolving: false,
          hasResolutionError: true,
          isAuthenticated: true,
          hasClubMembership: true,
          hasPlayerIdentityDraft: true,
          hasCurrentPlayer: true,
          needsCurrentPlayerCompletion: false,
        ),
        AppSessionGateKind.error,
      );
    });

    test('routes guests to the unauthenticated state', () {
      expect(
        resolveAppSessionGate(
          isResolving: false,
          hasResolutionError: false,
          isAuthenticated: false,
          hasClubMembership: false,
          hasPlayerIdentityDraft: false,
          hasCurrentPlayer: false,
          needsCurrentPlayerCompletion: false,
        ),
        AppSessionGateKind.unauthenticated,
      );
    });

    test('requires a player profile before club selection', () {
      expect(
        resolveAppSessionGate(
          isResolving: false,
          hasResolutionError: false,
          isAuthenticated: true,
          hasClubMembership: false,
          hasPlayerIdentityDraft: false,
          hasCurrentPlayer: false,
          needsCurrentPlayerCompletion: false,
        ),
        AppSessionGateKind.authenticatedNeedsPlayerProfile,
      );
    });

    test(
      'routes to club selection when auth is valid and the draft exists',
      () {
        expect(
          resolveAppSessionGate(
            isResolving: false,
            hasResolutionError: false,
            isAuthenticated: true,
            hasClubMembership: false,
            hasPlayerIdentityDraft: true,
            hasCurrentPlayer: false,
            needsCurrentPlayerCompletion: false,
          ),
          AppSessionGateKind.authenticatedNeedsClubSelection,
        );
      },
    );

    test(
      'keeps membership users on the profile gate until the player exists',
      () {
        expect(
          resolveAppSessionGate(
            isResolving: false,
            hasResolutionError: false,
            isAuthenticated: true,
            hasClubMembership: true,
            hasPlayerIdentityDraft: true,
            hasCurrentPlayer: false,
            needsCurrentPlayerCompletion: false,
          ),
          AppSessionGateKind.authenticatedNeedsPlayerProfile,
        );
      },
    );

    test('keeps incomplete players on the profile gate', () {
      expect(
        resolveAppSessionGate(
          isResolving: false,
          hasResolutionError: false,
          isAuthenticated: true,
          hasClubMembership: true,
          hasPlayerIdentityDraft: true,
          hasCurrentPlayer: true,
          needsCurrentPlayerCompletion: true,
        ),
        AppSessionGateKind.authenticatedNeedsPlayerProfile,
      );
    });

    test('routes fully resolved members to the club shell', () {
      expect(
        resolveAppSessionGate(
          isResolving: false,
          hasResolutionError: false,
          isAuthenticated: true,
          hasClubMembership: true,
          hasPlayerIdentityDraft: true,
          hasCurrentPlayer: true,
          needsCurrentPlayerCompletion: false,
        ),
        AppSessionGateKind.authenticatedWithClub,
      );
    });
  });
}
