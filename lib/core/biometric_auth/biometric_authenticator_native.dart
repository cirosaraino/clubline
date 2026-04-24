import 'package:local_auth/local_auth.dart';

import 'biometric_authenticator.dart';

class _LocalBiometricAuthenticator implements BiometricAuthenticator {
  _LocalBiometricAuthenticator() : _auth = LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<BiometricCapability> checkCapability() async {
    try {
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      if (!canCheckBiometrics) {
        return const BiometricCapability.unavailable();
      }

      final availableBiometrics = await _auth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        return const BiometricCapability(
          isSupported: true,
          hasEnrolledBiometrics: false,
        );
      }

      return BiometricCapability(
        isSupported: true,
        hasEnrolledBiometrics: true,
        preferredType: _resolvePreferredType(availableBiometrics),
      );
    } on LocalAuthException catch (error) {
      switch (error.code) {
        case LocalAuthExceptionCode.noBiometricHardware:
        case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
        case LocalAuthExceptionCode.noCredentialsSet:
          return const BiometricCapability.unavailable();
        case LocalAuthExceptionCode.noBiometricsEnrolled:
          return const BiometricCapability(
            isSupported: true,
            hasEnrolledBiometrics: false,
          );
        default:
          return const BiometricCapability.unavailable();
      }
    }
  }

  @override
  Future<BiometricAuthAttempt> authenticate({
    required String localizedReason,
  }) async {
    try {
      final didAuthenticate = await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (didAuthenticate) {
        return const BiometricAuthAttempt(didAuthenticate: true);
      }

      return const BiometricAuthAttempt(
        didAuthenticate: false,
        wasCanceled: true,
        message: 'Sblocco biometrico annullato.',
      );
    } on LocalAuthException catch (error) {
      switch (error.code) {
        case LocalAuthExceptionCode.userCanceled:
        case LocalAuthExceptionCode.systemCanceled:
        case LocalAuthExceptionCode.timeout:
          return const BiometricAuthAttempt(
            didAuthenticate: false,
            wasCanceled: true,
            message: 'Sblocco biometrico annullato.',
          );
        case LocalAuthExceptionCode.noBiometricHardware:
          return const BiometricAuthAttempt(
            didAuthenticate: false,
            message: 'Questo dispositivo non supporta la biometria.',
          );
        case LocalAuthExceptionCode.noBiometricsEnrolled:
          return const BiometricAuthAttempt(
            didAuthenticate: false,
            message: 'Nessuna biometria registrata sul dispositivo.',
          );
        case LocalAuthExceptionCode.temporaryLockout:
          return const BiometricAuthAttempt(
            didAuthenticate: false,
            message: 'Biometria temporaneamente bloccata. Riprova tra poco.',
          );
        case LocalAuthExceptionCode.biometricLockout:
          return const BiometricAuthAttempt(
            didAuthenticate: false,
            message:
                'Biometria bloccata. Sblocca il dispositivo e poi riprova.',
          );
        default:
          return BiometricAuthAttempt(
            didAuthenticate: false,
            message:
                error.description ??
                'Impossibile completare lo sblocco biometrico.',
          );
      }
    }
  }

  BiometricUnlockType _resolvePreferredType(List<BiometricType> biometrics) {
    if (biometrics.contains(BiometricType.face)) {
      return BiometricUnlockType.face;
    }

    if (biometrics.contains(BiometricType.fingerprint)) {
      return BiometricUnlockType.fingerprint;
    }

    return BiometricUnlockType.biometric;
  }
}

BiometricAuthenticator createPlatformBiometricAuthenticator() =>
    _LocalBiometricAuthenticator();
