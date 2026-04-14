import 'mobile_web_install_bridge_stub.dart'
    if (dart.library.html) 'mobile_web_install_bridge_web.dart' as impl;
import 'mobile_web_install_types.dart';

export 'mobile_web_install_types.dart';

MobileWebInstallBridge get mobileWebInstall => impl.mobileWebInstallBridge;
