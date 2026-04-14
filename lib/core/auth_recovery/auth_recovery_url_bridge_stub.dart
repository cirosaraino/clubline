import 'auth_recovery_url_types.dart';

final AuthRecoveryUrlBridge authRecoveryUrlBridge =
    _StubAuthRecoveryUrlBridge();

class _StubAuthRecoveryUrlBridge implements AuthRecoveryUrlBridge {
  @override
  Future<void> clearRecoverySessionCandidate() async {}

  @override
  AuthRecoverySessionCandidate? readRecoverySessionCandidate() {
    return null;
  }
}
