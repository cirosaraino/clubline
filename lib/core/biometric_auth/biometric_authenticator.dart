import 'biometric_authenticator_stub.dart'
    if (dart.library.io) 'biometric_authenticator_native.dart';

enum BiometricUnlockType { face, fingerprint, biometric }

class BiometricCapability {
  const BiometricCapability({
    required this.isSupported,
    required this.hasEnrolledBiometrics,
    this.preferredType = BiometricUnlockType.biometric,
  });

  const BiometricCapability.unavailable()
    : isSupported = false,
      hasEnrolledBiometrics = false,
      preferredType = BiometricUnlockType.biometric;

  final bool isSupported;
  final bool hasEnrolledBiometrics;
  final BiometricUnlockType preferredType;

  bool get isReadyForUnlock => isSupported && hasEnrolledBiometrics;

  String get preferenceLabel {
    switch (preferredType) {
      case BiometricUnlockType.face:
        return 'Face ID';
      case BiometricUnlockType.fingerprint:
        return 'Impronta digitale';
      case BiometricUnlockType.biometric:
        return 'biometria';
    }
  }

  String get promptLabel {
    switch (preferredType) {
      case BiometricUnlockType.face:
        return 'Face ID';
      case BiometricUnlockType.fingerprint:
        return 'impronta digitale';
      case BiometricUnlockType.biometric:
        return 'biometria';
    }
  }
}

class BiometricAuthAttempt {
  const BiometricAuthAttempt({
    required this.didAuthenticate,
    this.wasCanceled = false,
    this.message,
  });

  final bool didAuthenticate;
  final bool wasCanceled;
  final String? message;
}

abstract class BiometricAuthenticator {
  Future<BiometricCapability> checkCapability();

  Future<BiometricAuthAttempt> authenticate({required String localizedReason});
}

BiometricAuthenticator createBiometricAuthenticator() =>
    createPlatformBiometricAuthenticator();
