import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'app_realtime_bridge_types.dart';

final AppRealtimeBridge appRealtimeBridgeInstance = _WebAppRealtimeBridge();

class _WebAppRealtimeBridge implements AppRealtimeBridge {
  final StreamController<String> _messagesController =
      StreamController<String>.broadcast();

  web.EventSource? _eventSource;
  web.EventListener? _messageListener;
  web.EventListener? _openListener;
  web.EventListener? _errorListener;
  String? _activeUrl;
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Stream<String> get messages => _messagesController.stream;

  @override
  Future<void> connect(String url) async {
    if (_activeUrl == url && _eventSource != null) {
      return;
    }

    disconnect();
    _activeUrl = url;

    final source = web.EventSource(url);
    _eventSource = source;

    _messageListener = ((web.Event event) {
      final rawData = event.getProperty<JSAny?>('data'.toJS)?.dartify();
      if (rawData == null) {
        return;
      }

      final text = rawData.toString().trim();
      if (text.isEmpty) {
        return;
      }

      _messagesController.add(text);
    }).toJS;

    _openListener = ((web.Event _) {
      _connected = true;
    }).toJS;

    _errorListener = ((web.Event _) {
      _connected = false;
    }).toJS;

    source.addEventListener('message', _messageListener!);
    source.addEventListener('open', _openListener!);
    source.addEventListener('error', _errorListener!);
  }

  @override
  void disconnect() {
    final source = _eventSource;
    if (source != null) {
      if (_messageListener != null) {
        source.removeEventListener('message', _messageListener!);
      }
      if (_openListener != null) {
        source.removeEventListener('open', _openListener!);
      }
      if (_errorListener != null) {
        source.removeEventListener('error', _errorListener!);
      }
      source.close();
    }

    _eventSource = null;
    _messageListener = null;
    _openListener = null;
    _errorListener = null;
    _activeUrl = null;
    _connected = false;
  }
}
