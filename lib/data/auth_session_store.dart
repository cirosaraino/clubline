import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_session.dart';

class AuthSessionStore {
  AuthSessionStore();

  static const String _sessionKey = 'backend_auth_session_v1';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  Future<AuthSession?> readSession() async {
    final rawSession = await _readRawSession();
    if (rawSession == null || rawSession.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(rawSession);
    if (decoded is! Map) {
      return null;
    }

    return AuthSession.fromMap(Map<String, dynamic>.from(decoded));
  }

  Future<void> saveSession(AuthSession session) async {
    final rawSession = jsonEncode(session.toMap());
    if (kIsWeb) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_sessionKey, rawSession);
      return;
    }

    await _secureStorage.write(key: _sessionKey, value: rawSession);
  }

  Future<void> clear() async {
    if (kIsWeb) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_sessionKey);
      return;
    }

    await _secureStorage.delete(key: _sessionKey);
  }

  Future<String?> _readRawSession() async {
    if (kIsWeb) {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getString(_sessionKey);
    }

    return _secureStorage.read(key: _sessionKey);
  }
}
