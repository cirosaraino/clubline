import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'mobile_web_install_types.dart';

final MobileWebInstallBridge mobileWebInstallBridge = _WebMobileInstallBridge();

class _WebMobileInstallBridge implements MobileWebInstallBridge {
  _WebMobileInstallBridge() {
    _initialize();
  }

  final StreamController<void> _changesController =
      StreamController<void>.broadcast();

  late final web.EventListener _installAvailableListener =
      ((web.Event _) => _refreshAvailability()).toJS;
  late final web.EventListener _installedListener = ((web.Event _) {
    _deferredPromptEvent = null;
    _installed = true;
    _state.setProperty('deferredPrompt'.toJS, null);
    _state.setProperty('installed'.toJS, true.toJS);
    _changesController.add(null);
  }).toJS;

  JSObject? _deferredPromptEvent;
  bool _installed = false;
  bool _initialized = false;

  @override
  bool get isMobileBrowser {
    final userAgent = web.window.navigator.userAgent.toLowerCase();
    return userAgent.contains('android') ||
        userAgent.contains('iphone') ||
        userAgent.contains('ipad') ||
        userAgent.contains('ipod') ||
        userAgent.contains('mobile');
  }

  @override
  bool get isStandalone => _installed;

  @override
  bool get isIosSafari {
    final userAgent = web.window.navigator.userAgent.toLowerCase();
    final isAppleDevice = userAgent.contains('iphone') ||
        userAgent.contains('ipad') ||
        userAgent.contains('ipod');
    final isSafari = userAgent.contains('safari') &&
        !userAgent.contains('crios') &&
        !userAgent.contains('fxios') &&
        !userAgent.contains('edgios');
    return isAppleDevice && isSafari;
  }

  @override
  bool get canPromptInstall => _deferredPromptEvent != null;

  @override
  bool get canSuggestInstall => isMobileBrowser && !isStandalone;

  @override
  Stream<void> get changes => _changesController.stream;

  @override
  Future<MobileWebInstallPromptResult> promptInstall() async {
    _initialize();

    final deferredPrompt = _deferredPromptEvent;
    if (deferredPrompt == null) {
      return MobileWebInstallPromptResult.unavailable;
    }

    try {
      deferredPrompt.callMethodVarArgs('prompt'.toJS, const []);

      final choicePromise =
          deferredPrompt.getProperty<JSPromise<JSAny?>>('userChoice'.toJS);
      final userChoice = await choicePromise.toDart;
      final userChoiceObject = userChoice as JSObject?;
      final outcome = userChoiceObject
          ?.getProperty<JSAny?>('outcome'.toJS)
          ?.dartify()
          ?.toString();

      _deferredPromptEvent = null;
      _state.setProperty('deferredPrompt'.toJS, null);
      _changesController.add(null);

      return outcome == 'accepted'
          ? MobileWebInstallPromptResult.accepted
          : MobileWebInstallPromptResult.dismissed;
    } catch (_) {
      return MobileWebInstallPromptResult.unavailable;
    }
  }

  void _initialize() {
    if (_initialized) return;
    _initialized = true;

    _refreshAvailability();
    web.window.addEventListener(
      'ultras-pwa-install-available',
      _installAvailableListener,
    );
    web.window.addEventListener(
      'ultras-pwa-installed',
      _installedListener,
    );
  }

  void _refreshAvailability() {
    _deferredPromptEvent = _state.getProperty<JSObject?>('deferredPrompt'.toJS);
    _installed = _computeStandalone();
    _changesController.add(null);
  }

  JSObject get _state {
    final existing = web.window.getProperty<JSAny?>('__ultrasPwa'.toJS);
    if (existing != null) {
      return existing as JSObject;
    }

    final fallback = <String, Object?>{
      'deferredPrompt': null,
      'installed': _computeStandalone(),
    }.jsify() as JSObject;
    web.window.setProperty('__ultrasPwa'.toJS, fallback);
    return fallback;
  }

  bool _computeStandalone() {
    final standalone = web.window.navigator.getProperty<JSAny?>(
      'standalone'.toJS,
    );
    final displayModeStandalone =
        web.window.matchMedia('(display-mode: standalone)').matches;
    return displayModeStandalone || standalone?.dartify() == true;
  }
}
