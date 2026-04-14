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
  DateTime? _lastConnectAttemptAt;

  @override
  bool get isConnected => _connected;

  @override
  Stream<String> get messages => _messagesController.stream;

  @override
  Future<void> connect(String url) async {
    if (_activeUrl == url && _eventSource != null) {
      final readyState = _readReadyState(_eventSource!);
      final isOpenOrConnecting = readyState == 0 || readyState == 1;
      if (readyState == 1 && isOpenOrConnecting) {
        _connected = true;
        return;
      }

      if (readyState == 0 && isOpenOrConnecting) {
        final lastAttempt = _lastConnectAttemptAt;
        if (lastAttempt != null &&
            DateTime.now().difference(lastAttempt) <
                const Duration(seconds: 10)) {
          return;
        }
      }

      if (_connected && isOpenOrConnecting) {
        return;
      }

      disconnect();
    }

    disconnect();
    _activeUrl = url;
    _lastConnectAttemptAt = DateTime.now();

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

      final source = _eventSource;
      if (source == null) {
        return;
      }

      final readyState = _readReadyState(source);
      if (readyState == 2) {
        disconnect();
      }
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
    _lastConnectAttemptAt = null;
    _connected = false;
  }

  int _readReadyState(web.EventSource source) {
    final rawValue = source.getProperty<JSAny?>('readyState'.toJS)?.dartify();
    if (rawValue is num) {
      return rawValue.toInt();
    }

    return 2;
  }
}
