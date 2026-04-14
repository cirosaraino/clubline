import 'dart:async';

enum MobileWebInstallPromptResult {
  unsupported,
  unavailable,
  accepted,
  dismissed,
}

abstract class MobileWebInstallBridge {
  bool get isMobileBrowser;
  bool get isStandalone;
  bool get isIosSafari;
  bool get canPromptInstall;
  bool get canSuggestInstall;
  Stream<void> get changes;

  Future<MobileWebInstallPromptResult> promptInstall();
}
