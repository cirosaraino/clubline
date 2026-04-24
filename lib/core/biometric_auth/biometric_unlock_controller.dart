import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../data/biometric_unlock_settings_store.dart';
import '../app_session.dart';
import 'biometric_authenticator.dart';

class BiometricUnlockController extends ChangeNotifier
    with WidgetsBindingObserver {
  BiometricUnlockController({
    required AppSessionController sessionController,
    BiometricUnlockSettingsStore? settingsStore,
    BiometricAuthenticator? authenticator,
  }) : _sessionController = sessionController,
       _settingsStore = settingsStore ?? BiometricUnlockSettingsStore(),
       _authenticator = authenticator ?? createBiometricAuthenticator() {
    WidgetsBinding.instance.addObserver(this);
    _sessionController.addListener(_handleSessionChanged);
    unawaited(_syncWithSessionState());
  }

  final AppSessionController _sessionController;
  final BiometricUnlockSettingsStore _settingsStore;
  final BiometricAuthenticator _authenticator;

  String? _currentUserId;
  BiometricCapability _capability = const BiometricCapability.unavailable();
  bool _isBiometricUnlockEnabled = false;
  bool _isPrompting = false;
  bool _isLocked = false;
  bool _isCheckingConfiguration = false;
  bool _hasCompletedInitialSessionEvaluation = false;
  bool _requireUnlockOnNextResume = false;
  String? _statusMessage;
  bool _disposed = false;

  bool get isBiometricUnlockEnabled => _isBiometricUnlockEnabled;
  bool get isPrompting => _isPrompting;
  bool get isLocked => _isLocked;
  bool get isCheckingConfiguration => _isCheckingConfiguration;
  bool get isPreparingInitialGate =>
      _sessionController.isAuthenticated &&
      !_hasCompletedInitialSessionEvaluation &&
      _isCheckingConfiguration;
  bool get hasSupportedBiometricHardware => _capability.isSupported;
  bool get hasEnrolledBiometrics => _capability.hasEnrolledBiometrics;
  bool get canOfferBiometricUnlock =>
      _sessionController.isAuthenticated &&
      hasSupportedBiometricHardware &&
      hasEnrolledBiometrics;
  bool get shouldBlockAccess =>
      _sessionController.isAuthenticated &&
      (isPreparingInitialGate || (_isBiometricUnlockEnabled && _isLocked));
  String? get statusMessage => _statusMessage;
  String get preferenceLabel => _capability.preferenceLabel;
  String get unlockActionLabel {
    switch (_capability.preferredType) {
      case BiometricUnlockType.face:
        return 'Sblocca con Face ID';
      case BiometricUnlockType.fingerprint:
        return 'Sblocca con impronta';
      case BiometricUnlockType.biometric:
        return 'Sblocca con biometria';
    }
  }

  String get availabilityDescription {
    if (!_sessionController.isAuthenticated) {
      return 'Accedi prima per gestire lo sblocco biometrico di questa sessione.';
    }

    if (!hasSupportedBiometricHardware) {
      return 'Questo dispositivo non supporta Face ID o impronta digitale.';
    }

    if (!hasEnrolledBiometrics) {
      return 'Il dispositivo supporta la biometria, ma non risultano Face ID o impronte registrate.';
    }

    if (_isBiometricUnlockEnabled) {
      return 'Alla riapertura dell app verra richiesto ${_capability.promptLabel} per sbloccare una sessione Clubline gia autenticata.';
    }

    return 'Attiva ${_capability.promptLabel} per proteggere localmente una sessione Clubline gia autenticata.';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_sessionController.isAuthenticated || !_isBiometricUnlockEnabled) {
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (_isPrompting) {
        return;
      }
      _requireUnlockOnNextResume = true;
      return;
    }

    if (state == AppLifecycleState.resumed && _requireUnlockOnNextResume) {
      _requireUnlockOnNextResume = false;
      _isLocked = true;
      _notifyIfMounted();
      unawaited(requestUnlock());
    }
  }

  Future<String?> setBiometricUnlockEnabled(bool enabled) async {
    final authUser = _sessionController.authUser;
    if (authUser == null || authUser.id.trim().isEmpty) {
      return 'Accedi prima per attivare lo sblocco biometrico.';
    }

    _currentUserId = authUser.id.trim();
    _isCheckingConfiguration = true;
    _notifyIfMounted();

    try {
      _capability = await _authenticator.checkCapability();
      if (enabled) {
        if (!_capability.isSupported) {
          return 'Questo dispositivo non supporta la biometria.';
        }

        if (!_capability.hasEnrolledBiometrics) {
          return 'Configura prima Face ID o un impronta sul dispositivo.';
        }

        final attempt = await _authenticator.authenticate(
          localizedReason:
              'Conferma la tua identita per attivare lo sblocco biometrico di Clubline.',
        );
        if (!attempt.didAuthenticate) {
          return attempt.message ??
              'Attivazione biometrica annullata. Nessuna modifica salvata.';
        }
      }

      await _settingsStore.writeEnabledForUser(_currentUserId!, enabled);
      _isBiometricUnlockEnabled = enabled;
      _isLocked = false;
      _statusMessage = enabled
          ? 'Sblocco biometrico attivato.'
          : 'Sblocco biometrico disattivato.';
      _notifyIfMounted();
      return null;
    } finally {
      _isCheckingConfiguration = false;
      _notifyIfMounted();
    }
  }

  Future<void> requestUnlock() async {
    if (!_sessionController.isAuthenticated || !_isBiometricUnlockEnabled) {
      _isLocked = false;
      _notifyIfMounted();
      return;
    }

    if (_isPrompting) {
      return;
    }

    _capability = await _authenticator.checkCapability();
    if (!_capability.isSupported) {
      _isLocked = true;
      _statusMessage =
          'Questo dispositivo non supporta piu la biometria. Accedi normalmente e disattiva lo sblocco biometrico dalle impostazioni.';
      _notifyIfMounted();
      return;
    }

    if (!_capability.hasEnrolledBiometrics) {
      _isLocked = true;
      _statusMessage =
          'Non risultano biometrie registrate sul dispositivo. Accedi normalmente e aggiorna l impostazione biometrica.';
      _notifyIfMounted();
      return;
    }

    _isPrompting = true;
    _statusMessage = null;
    _notifyIfMounted();

    try {
      final attempt = await _authenticator.authenticate(
        localizedReason:
            'Autenticati con ${_capability.promptLabel} per sbloccare Clubline.',
      );

      if (attempt.didAuthenticate) {
        _isLocked = false;
        _statusMessage = null;
        _notifyIfMounted();
        return;
      }

      _isLocked = true;
      _statusMessage =
          attempt.message ??
          'Sblocco biometrico non riuscito. Riprova oppure usa il login normale.';
    } finally {
      _isPrompting = false;
      _notifyIfMounted();
    }
  }

  Future<void> _syncWithSessionState() async {
    if (_disposed) {
      return;
    }

    if (!_hasCompletedInitialSessionEvaluation &&
        _sessionController.isLoading) {
      return;
    }

    final authUser = _sessionController.authUser;
    if (authUser == null || authUser.id.trim().isEmpty) {
      _currentUserId = null;
      _isBiometricUnlockEnabled = false;
      _isPrompting = false;
      _isLocked = false;
      _requireUnlockOnNextResume = false;
      _statusMessage = null;
      if (!_sessionController.isLoading) {
        _hasCompletedInitialSessionEvaluation = true;
      }
      _notifyIfMounted();
      return;
    }

    final nextUserId = authUser.id.trim();
    final isFirstResolvedSession =
        !_hasCompletedInitialSessionEvaluation && !_sessionController.isLoading;
    final accountChanged = _currentUserId != nextUserId;

    if (accountChanged) {
      _currentUserId = nextUserId;
      _isCheckingConfiguration = true;
      _notifyIfMounted();
      try {
        _capability = await _authenticator.checkCapability();
        _isBiometricUnlockEnabled = await _settingsStore.readEnabledForUser(
          nextUserId,
        );
      } finally {
        _isCheckingConfiguration = false;
      }

      if (isFirstResolvedSession) {
        _hasCompletedInitialSessionEvaluation = true;
        _isLocked = _isBiometricUnlockEnabled;
        _notifyIfMounted();
        if (_isLocked) {
          unawaited(requestUnlock());
        }
        return;
      }

      _isLocked = false;
      _statusMessage = null;
      _notifyIfMounted();
      return;
    }

    if (isFirstResolvedSession) {
      _hasCompletedInitialSessionEvaluation = true;
      if (_isBiometricUnlockEnabled) {
        _isLocked = true;
        _notifyIfMounted();
        unawaited(requestUnlock());
        return;
      }
    }

    _notifyIfMounted();
  }

  void _handleSessionChanged() {
    unawaited(_syncWithSessionState());
  }

  void _notifyIfMounted() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _sessionController.removeListener(_handleSessionChanged);
    super.dispose();
  }
}

class BiometricUnlockScope
    extends InheritedNotifier<BiometricUnlockController> {
  const BiometricUnlockScope({
    super.key,
    required BiometricUnlockController controller,
    required super.child,
  }) : super(notifier: controller);

  static BiometricUnlockController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<BiometricUnlockScope>();
    assert(scope != null, 'BiometricUnlockScope non trovato nel widget tree.');
    return scope!.notifier!;
  }

  static BiometricUnlockController read(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<BiometricUnlockScope>();
    final scope = element?.widget as BiometricUnlockScope?;
    assert(scope != null, 'BiometricUnlockScope non trovato nel widget tree.');
    return scope!.notifier!;
  }
}
