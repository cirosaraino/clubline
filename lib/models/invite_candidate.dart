enum InviteCandidateReason {
  pendingJoinRequestSameClub,
  pendingJoinRequestOtherClub;

  static InviteCandidateReason? fromValue(String? value) {
    return switch (value?.trim()) {
      'pending_join_request_same_club' =>
        InviteCandidateReason.pendingJoinRequestSameClub,
      'pending_join_request_other_club' =>
        InviteCandidateReason.pendingJoinRequestOtherClub,
      _ => null,
    };
  }

  String get value => switch (this) {
    InviteCandidateReason.pendingJoinRequestSameClub =>
      'pending_join_request_same_club',
    InviteCandidateReason.pendingJoinRequestOtherClub =>
      'pending_join_request_other_club',
  };
}

class InviteCandidate {
  const InviteCandidate({
    required this.userId,
    required this.playerProfileId,
    required this.nome,
    required this.cognome,
    required this.invitable,
    this.accountEmail,
    this.idConsole,
    this.primaryRole,
    this.reason,
  });

  final String userId;
  final dynamic playerProfileId;
  final String nome;
  final String cognome;
  final String? accountEmail;
  final String? idConsole;
  final String? primaryRole;
  final bool invitable;
  final InviteCandidateReason? reason;

  factory InviteCandidate.fromMap(Map<String, dynamic> map) {
    return InviteCandidate(
      userId: map['user_id']?.toString() ?? '',
      playerProfileId: map['player_profile_id'],
      nome: map['nome']?.toString().trim() ?? '',
      cognome: map['cognome']?.toString().trim() ?? '',
      accountEmail: map['account_email']?.toString(),
      idConsole: map['id_console']?.toString(),
      primaryRole: map['primary_role']?.toString(),
      invitable: map['invitable'] == true,
      reason: InviteCandidateReason.fromValue(map['reason']?.toString()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'player_profile_id': playerProfileId,
      'nome': nome,
      'cognome': cognome,
      'account_email': accountEmail,
      'id_console': idConsole,
      'primary_role': primaryRole,
      'invitable': invitable,
      'reason': reason?.value,
    };
  }

  String get fullName => '$nome $cognome'.trim();
}
