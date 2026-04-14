import 'dart:async';

import 'mobile_web_install_types.dart';

final MobileWebInstallBridge mobileWebInstallBridge = _StubMobileWebInstallBridge();

class _StubMobileWebInstallBridge implements MobileWebInstallBridge {
  @override
  bool get isMobileBrowser => false;

  @override
  bool get isStandalone => false;

  @override
  bool get isIosSafari => false;

  @override
  bool get canPromptInstall => false;

  @override
  bool get canSuggestInstall => false;

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<MobileWebInstallPromptResult> promptInstall() async {
    return MobileWebInstallPromptResult.unsupported;
  }
}
