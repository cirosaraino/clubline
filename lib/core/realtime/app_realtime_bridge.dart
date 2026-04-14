import 'app_realtime_bridge_stub.dart'
    if (dart.library.html) 'app_realtime_bridge_web.dart' as impl;
import 'app_realtime_bridge_types.dart';

export 'app_realtime_bridge_types.dart';

AppRealtimeBridge get appRealtimeBridge => impl.appRealtimeBridgeInstance;
