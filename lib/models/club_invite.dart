import 'club.dart';
import 'cursor_pagination.dart';
import 'membership.dart';
import 'player_profile.dart';

DateTime? _parseInviteDateTime(dynamic value) {
  if (value == null) {
    return null;
  }

  return DateTime.tryParse(value.toString())?.toLocal();
}

enum ClubInviteStatus {
  pending,
  accepted,
  declined,
  revoked,
  expired;

  static ClubInviteStatus fromValue(String? value) {
    return switch (value?.trim()) {
      'accepted' => ClubInviteStatus.accepted,
      'declined' => ClubInviteStatus.declined,
      'revoked' => ClubInviteStatus.revoked,
      'expired' => ClubInviteStatus.expired,
      _ => ClubInviteStatus.pending,
    };
  }

  String get value => name;
}

enum ClubInviteListStatus {
  pending,
  all;

  String get value => name;
}

class ClubInvite {
  const ClubInvite({
    required this.id,
    required this.clubId,
    required this.targetUserId,
    required this.targetNome,
    required this.targetCognome,
    required this.status,
    this.club,
    this.createdByUserId,
    this.createdByMembershipId,
    this.targetPlayerProfileId,
    this.targetAccountEmail,
    this.targetIdConsole,
    this.targetPrimaryRole,
    this.resolvedAt,
    this.resolvedByUserId,
    this.resolvedByMembershipId,
    this.acceptedMembershipId,
    this.acceptedPlayerId,
    this.createdAt,
    this.updatedAt,
  });

  final dynamic id;
  final dynamic clubId;
  final Club? club;
  final String? createdByUserId;
  final dynamic createdByMembershipId;
  final String targetUserId;
  final dynamic targetPlayerProfileId;
  final String? targetAccountEmail;
  final String targetNome;
  final String targetCognome;
  final String? targetIdConsole;
  final String? targetPrimaryRole;
  final ClubInviteStatus status;
  final DateTime? resolvedAt;
  final String? resolvedByUserId;
  final dynamic resolvedByMembershipId;
  final dynamic acceptedMembershipId;
  final dynamic acceptedPlayerId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ClubInvite.fromMap(Map<String, dynamic> map) {
    final rawClub = map['club'];

    return ClubInvite(
      id: map['id'],
      clubId: map['club_id'],
      club: rawClub is Map
          ? Club.fromMap(Map<String, dynamic>.from(rawClub))
          : null,
      createdByUserId: map['created_by_user_id']?.toString(),
      createdByMembershipId: map['created_by_membership_id'],
      targetUserId: map['target_user_id']?.toString() ?? '',
      targetPlayerProfileId: map['target_player_profile_id'],
      targetAccountEmail: map['target_account_email']?.toString(),
      targetNome: map['target_nome']?.toString().trim() ?? '',
      targetCognome: map['target_cognome']?.toString().trim() ?? '',
      targetIdConsole: map['target_id_console']?.toString(),
      targetPrimaryRole: map['target_primary_role']?.toString(),
      status: ClubInviteStatus.fromValue(map['status']?.toString()),
      resolvedAt: _parseInviteDateTime(map['resolved_at']),
      resolvedByUserId: map['resolved_by_user_id']?.toString(),
      resolvedByMembershipId: map['resolved_by_membership_id'],
      acceptedMembershipId: map['accepted_membership_id'],
      acceptedPlayerId: map['accepted_player_id'],
      createdAt: _parseInviteDateTime(map['created_at']),
      updatedAt: _parseInviteDateTime(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'club_id': clubId,
      'club': club?.toMap(),
      'created_by_user_id': createdByUserId,
      'created_by_membership_id': createdByMembershipId,
      'target_user_id': targetUserId,
      'target_player_profile_id': targetPlayerProfileId,
      'target_account_email': targetAccountEmail,
      'target_nome': targetNome,
      'target_cognome': targetCognome,
      'target_id_console': targetIdConsole,
      'target_primary_role': targetPrimaryRole,
      'status': status.value,
      'resolved_at': resolvedAt?.toUtc().toIso8601String(),
      'resolved_by_user_id': resolvedByUserId,
      'resolved_by_membership_id': resolvedByMembershipId,
      'accepted_membership_id': acceptedMembershipId,
      'accepted_player_id': acceptedPlayerId,
      'created_at': createdAt?.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
    };
  }

  String get fullName => '$targetNome $targetCognome'.trim();

  String get clubDisplayName =>
      club?.name.trim().isNotEmpty == true ? club!.name : 'Club #$clubId';

  bool get isPending => status == ClubInviteStatus.pending;

  ClubInvite copyWith({
    dynamic id,
    dynamic clubId,
    Club? club,
    String? createdByUserId,
    dynamic createdByMembershipId,
    String? targetUserId,
    dynamic targetPlayerProfileId,
    String? targetAccountEmail,
    String? targetNome,
    String? targetCognome,
    String? targetIdConsole,
    String? targetPrimaryRole,
    ClubInviteStatus? status,
    DateTime? resolvedAt,
    bool clearResolvedAt = false,
    String? resolvedByUserId,
    dynamic resolvedByMembershipId,
    dynamic acceptedMembershipId,
    dynamic acceptedPlayerId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClubInvite(
      id: id ?? this.id,
      clubId: clubId ?? this.clubId,
      club: club ?? this.club,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdByMembershipId:
          createdByMembershipId ?? this.createdByMembershipId,
      targetUserId: targetUserId ?? this.targetUserId,
      targetPlayerProfileId:
          targetPlayerProfileId ?? this.targetPlayerProfileId,
      targetAccountEmail: targetAccountEmail ?? this.targetAccountEmail,
      targetNome: targetNome ?? this.targetNome,
      targetCognome: targetCognome ?? this.targetCognome,
      targetIdConsole: targetIdConsole ?? this.targetIdConsole,
      targetPrimaryRole: targetPrimaryRole ?? this.targetPrimaryRole,
      status: status ?? this.status,
      resolvedAt: clearResolvedAt ? null : (resolvedAt ?? this.resolvedAt),
      resolvedByUserId: resolvedByUserId ?? this.resolvedByUserId,
      resolvedByMembershipId:
          resolvedByMembershipId ?? this.resolvedByMembershipId,
      acceptedMembershipId: acceptedMembershipId ?? this.acceptedMembershipId,
      acceptedPlayerId: acceptedPlayerId ?? this.acceptedPlayerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ClubInviteListResult {
  const ClubInviteListResult({required this.invites, required this.pagination});

  final List<ClubInvite> invites;
  final CursorPagination pagination;

  factory ClubInviteListResult.fromMap(Map<String, dynamic> map) {
    final rawInvites = map['invites'];
    final rawPagination = map['pagination'];

    return ClubInviteListResult(
      invites: rawInvites is Iterable
          ? rawInvites
                .whereType<Map>()
                .map(
                  (invite) =>
                      ClubInvite.fromMap(Map<String, dynamic>.from(invite)),
                )
                .toList(growable: false)
          : const [],
      pagination: rawPagination is Map
          ? CursorPagination.fromMap(Map<String, dynamic>.from(rawPagination))
          : const CursorPagination(limit: 20, hasMore: false),
    );
  }
}

class ClubInviteAcceptResult {
  const ClubInviteAcceptResult({
    required this.invite,
    required this.membership,
    required this.player,
  });

  final ClubInvite invite;
  final Membership membership;
  final PlayerProfile player;

  factory ClubInviteAcceptResult.fromMap(Map<String, dynamic> map) {
    return ClubInviteAcceptResult(
      invite: ClubInvite.fromMap(
        Map<String, dynamic>.from(map['invite'] as Map),
      ),
      membership: Membership.fromMap(
        Map<String, dynamic>.from(map['membership'] as Map),
      ),
      player: PlayerProfile.fromMap(
        Map<String, dynamic>.from(map['player'] as Map),
      ),
    );
  }
}
