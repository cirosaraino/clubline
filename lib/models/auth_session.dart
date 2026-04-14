import 'authenticated_user.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final AuthenticatedUser user;
  final DateTime? expiresAt;

  factory AuthSession.fromMap(Map<String, dynamic> map) {
    final rawSession = map['session'] is Map
        ? Map<String, dynamic>.from(map['session'] as Map)
        : map;
    final rawUser = rawSession['user'] is Map
        ? Map<String, dynamic>.from(rawSession['user'] as Map)
        : const <String, dynamic>{};
    final rawExpiresAt = rawSession['expiresAt'] ?? rawSession['expires_at'];

    return AuthSession(
      accessToken: rawSession['accessToken']?.toString() ??
          rawSession['access_token']?.toString() ??
          '',
      refreshToken: rawSession['refreshToken']?.toString() ??
          rawSession['refresh_token']?.toString() ??
          '',
      user: AuthenticatedUser.fromMap(rawUser),
      expiresAt: rawExpiresAt == null
          ? null
          : DateTime.tryParse(rawExpiresAt.toString())?.toLocal(),
    );
  }

  AuthSession copyWith({
    String? accessToken,
    String? refreshToken,
    AuthenticatedUser? user,
    DateTime? expiresAt,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      user: user ?? this.user,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresAt': expiresAt?.toUtc().toIso8601String(),
      'user': user.toMap(),
    };
  }
}
