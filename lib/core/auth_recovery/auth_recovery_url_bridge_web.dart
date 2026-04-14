import 'package:web/web.dart' as web;

import 'auth_recovery_url_types.dart';

final AuthRecoveryUrlBridge authRecoveryUrlBridge =
    _WebAuthRecoveryUrlBridge();

class _WebAuthRecoveryUrlBridge implements AuthRecoveryUrlBridge {
  @override
  AuthRecoverySessionCandidate? readRecoverySessionCandidate() {
    final currentUri = Uri.base;
    final fragment = currentUri.fragment;
    if (fragment.isEmpty) {
      return null;
    }

    final fragmentParams = Uri.splitQueryString(fragment);
    if (fragmentParams['type'] != 'recovery') {
      return null;
    }

    final accessToken = fragmentParams['access_token']?.trim() ?? '';
    final refreshToken = fragmentParams['refresh_token']?.trim() ?? '';
    final expiresAtRaw = fragmentParams['expires_at']?.trim();
    final expiresAtEpoch = expiresAtRaw == null ? null : int.tryParse(expiresAtRaw);

    if (accessToken.isEmpty || refreshToken.isEmpty) {
      return null;
    }

    return AuthRecoverySessionCandidate(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAtEpoch == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              expiresAtEpoch * 1000,
              isUtc: true,
            ).toLocal(),
    );
  }

  @override
  Future<void> clearRecoverySessionCandidate() async {
    final currentUri = Uri.base;
    final cleanedUri = Uri(
      path: currentUri.path,
      queryParameters:
          currentUri.queryParameters.isEmpty ? null : currentUri.queryParameters,
    );

    web.window.history.replaceState(
      null,
      '',
      cleanedUri.toString(),
    );
  }
}
