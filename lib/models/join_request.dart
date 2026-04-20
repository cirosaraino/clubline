import 'club.dart';

class JoinRequest {
  const JoinRequest({
    required this.id,
    required this.clubId,
    required this.status,
    required this.requestedNome,
    required this.requestedCognome,
    this.club,
    this.createdAt,
  });

  final dynamic id;
  final dynamic clubId;
  final String status;
  final String requestedNome;
  final String requestedCognome;
  final Club? club;
  final DateTime? createdAt;

  factory JoinRequest.fromMap(Map<String, dynamic> map) {
    final rawClub = map['club'];
    return JoinRequest(
      id: map['id'],
      clubId: map['club_id'],
      status: map['status']?.toString() ?? 'pending',
      requestedNome: map['requested_nome']?.toString().trim() ?? '',
      requestedCognome: map['requested_cognome']?.toString().trim() ?? '',
      club: rawClub is Map ? Club.fromMap(Map<String, dynamic>.from(rawClub)) : null,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString())?.toLocal(),
    );
  }

  bool get isPending => status == 'pending';
}
