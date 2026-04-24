import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricUnlockSettingsStore {
  BiometricUnlockSettingsStore();

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _keyPrefix = 'biometric_unlock_enabled_v1';

  Future<bool> readEnabledForUser(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return false;
    }

    final rawValue = await _readValue(_keyForUser(normalizedUserId));
    return rawValue == 'true';
  }

  Future<void> writeEnabledForUser(String userId, bool enabled) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return;
    }

    final key = _keyForUser(normalizedUserId);
    if (!enabled) {
      await _deleteValue(key);
      return;
    }

    await _writeValue(key, 'true');
  }

  String _keyForUser(String userId) => '$_keyPrefix::$userId';

  Future<String?> _readValue(String key) async {
    if (kIsWeb) {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getString(key);
    }

    return _secureStorage.read(key: key);
  }

  Future<void> _writeValue(String key, String value) async {
    if (kIsWeb) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(key, value);
      return;
    }

    await _secureStorage.write(key: key, value: value);
  }

  Future<void> _deleteValue(String key) async {
    if (kIsWeb) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(key);
      return;
    }

    await _secureStorage.delete(key: key);
  }
}
