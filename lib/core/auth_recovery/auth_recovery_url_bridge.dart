import 'auth_recovery_url_bridge_stub.dart'
    if (dart.library.html) 'auth_recovery_url_bridge_web.dart' as impl;
import 'auth_recovery_url_types.dart';

export 'auth_recovery_url_types.dart';

AuthRecoveryUrlBridge get authRecoveryUrlBridge => impl.authRecoveryUrlBridge;
