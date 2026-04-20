class AuthenticatedUser {
  const AuthenticatedUser({
    required this.id,
    required this.email,
    this.emailVerified = false,
    this.emailVerifiedAt,
  });

  final String id;
  final String email;
  final bool emailVerified;
  final DateTime? emailVerifiedAt;

  factory AuthenticatedUser.fromMap(Map<String, dynamic> map) {
    return AuthenticatedUser(
      id: map['id']?.toString() ?? '',
      email: map['email']?.toString().trim() ?? '',
      emailVerified: map['emailVerified'] == true || map['email_verified'] == true,
      emailVerifiedAt: map['emailVerifiedAt'] == null && map['email_verified_at'] == null
          ? null
          : DateTime.tryParse(
              (map['emailVerifiedAt'] ?? map['email_verified_at']).toString(),
            )?.toLocal(),
    );
  }

  AuthenticatedUser copyWith({
    String? id,
    String? email,
    bool? emailVerified,
    DateTime? emailVerifiedAt,
  }) {
    return AuthenticatedUser(
      id: id ?? this.id,
      email: email ?? this.email,
      emailVerified: emailVerified ?? this.emailVerified,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'emailVerified': emailVerified,
      'emailVerifiedAt': emailVerifiedAt?.toUtc().toIso8601String(),
    };
  }
}
