class Membership {
  const Membership({
    required this.id,
    required this.clubId,
    required this.role,
    required this.status,
    this.leftAt,
  });

  final dynamic id;
  final dynamic clubId;
  final String role;
  final String status;
  final DateTime? leftAt;

  factory Membership.fromMap(Map<String, dynamic> map) {
    return Membership(
      id: map['id'],
      clubId: map['club_id'],
      role: map['role']?.toString() ?? 'player',
      status: map['status']?.toString() ?? 'active',
      leftAt: map['left_at'] == null
          ? null
          : DateTime.tryParse(map['left_at'].toString())?.toLocal(),
    );
  }

  bool get isActive => status == 'active';
  bool get isCaptain => role == 'captain';
  bool get isViceCaptain => role == 'vice_captain';
}
