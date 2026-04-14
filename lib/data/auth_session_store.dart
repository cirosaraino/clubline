import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_session.dart';

class AuthSessionStore {
  AuthSessionStore();

  static const String _sessionKey = 'backend_auth_session_v1';

  Future<AuthSession?> readSession() async {
    final preferences = await SharedPreferences.getInstance();
    final rawSession = preferences.getString(_sessionKey);
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
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_sessionKey, jsonEncode(session.toMap()));
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_sessionKey);
  }
}
