import 'biometric_authenticator.dart';

class _UnsupportedBiometricAuthenticator implements BiometricAuthenticator {
  const _UnsupportedBiometricAuthenticator();

  @override
  Future<BiometricCapability> checkCapability() async {
    return const BiometricCapability.unavailable();
  }

  @override
  Future<BiometricAuthAttempt> authenticate({
    required String localizedReason,
  }) async {
    return const BiometricAuthAttempt(
      didAuthenticate: false,
      message: 'Biometria non disponibile su questa piattaforma.',
    );
  }
}

BiometricAuthenticator createPlatformBiometricAuthenticator() =>
    const _UnsupportedBiometricAuthenticator();
