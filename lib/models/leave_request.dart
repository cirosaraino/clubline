class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.membershipId,
    required this.status,
    this.createdAt,
  });

  final dynamic id;
  final dynamic membershipId;
  final String status;
  final DateTime? createdAt;

  factory LeaveRequest.fromMap(Map<String, dynamic> map) {
    return LeaveRequest(
      id: map['id'],
      membershipId: map['membership_id'],
      status: map['status']?.toString() ?? 'pending',
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString())?.toLocal(),
    );
  }

  bool get isPending => status == 'pending';
}
