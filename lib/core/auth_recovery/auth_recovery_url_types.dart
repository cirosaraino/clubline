class AuthRecoverySessionCandidate {
  const AuthRecoverySessionCandidate({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime? expiresAt;
}

abstract class AuthRecoveryUrlBridge {
  AuthRecoverySessionCandidate? readRecoverySessionCandidate();

  Future<void> clearRecoverySessionCandidate();
}
