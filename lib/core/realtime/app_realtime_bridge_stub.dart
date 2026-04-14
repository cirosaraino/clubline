import 'app_realtime_bridge_types.dart';

final AppRealtimeBridge appRealtimeBridgeInstance = _StubAppRealtimeBridge();

class _StubAppRealtimeBridge implements AppRealtimeBridge {
  @override
  bool get isConnected => false;

  @override
  Stream<String> get messages => const Stream<String>.empty();

  @override
  Future<void> connect(String url) async {}

  @override
  void disconnect() {}
}
