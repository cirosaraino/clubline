import 'dart:async';

abstract class AppRealtimeBridge {
  bool get isConnected;
  Stream<String> get messages;

  Future<void> connect(String url);
  void disconnect();
}
