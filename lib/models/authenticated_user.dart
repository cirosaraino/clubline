class AuthenticatedUser {
  const AuthenticatedUser({
    required this.id,
    required this.email,
  });

  final String id;
  final String email;

  factory AuthenticatedUser.fromMap(Map<String, dynamic> map) {
    return AuthenticatedUser(
      id: map['id']?.toString() ?? '',
      email: map['email']?.toString().trim() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
    };
  }
}
