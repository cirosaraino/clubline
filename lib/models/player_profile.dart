import '../core/player_formatters.dart';
import '../core/player_constants.dart';
import 'vice_permissions.dart';

class PlayerProfile {
  const PlayerProfile({
    this.id,
    this.clubId,
    this.membershipId,
    required this.nome,
    required this.cognome,
    this.authUserId,
    this.accountEmail,
    this.shirtNumber,
    this.primaryRole,
    this.secondaryRoles = const [],
    this.idConsole,
    this.teamRole = 'player',
    this.vicePermissions = VicePermissions.defaults,
  });

  final dynamic id;
  final dynamic clubId;
  final dynamic membershipId;
  final String nome;
  final String cognome;
  final String? authUserId;
  final String? accountEmail;
  final int? shirtNumber;
  final String? primaryRole;
  final List<String> secondaryRoles;
  final String? idConsole;
  final String teamRole;
  final VicePermissions vicePermissions;

  static int? _parseShirtNumber(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString().trim() ?? '');
  }

  static String? _normalizeOptionalText(dynamic value) {
    final trimmed = value?.toString().trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }

  factory PlayerProfile.fromMap(Map<String, dynamic> map) {
    final rawSecondaryRoles = map['secondary_roles'];

    return PlayerProfile(
      id: map['id'],
      clubId: map['club_id'],
      membershipId: map['membership_id'],
      nome: map['nome']?.toString() ?? '',
      cognome: map['cognome']?.toString() ?? '',
      authUserId: map['auth_user_id']?.toString(),
      accountEmail: normalizePlayerAccountEmail(
        map['account_email']?.toString(),
      ),
      shirtNumber: _parseShirtNumber(map['shirt_number']),
      primaryRole: _normalizeOptionalText(map['primary_role']),
      secondaryRoles: normalizeRoleCodes([
        if (rawSecondaryRoles is Iterable)
          ...rawSecondaryRoles.map((role) => role?.toString())
        else if (rawSecondaryRoles is String)
          rawSecondaryRoles,
        map['secondary_role']?.toString(),
      ]),
      idConsole: _normalizeOptionalText(map['id_console']),
      teamRole: normalizeTeamRole(map['team_role']?.toString()),
      vicePermissions: VicePermissions.defaults,
    );
  }

  PlayerProfile copyWith({
    dynamic id,
    dynamic clubId,
    dynamic membershipId,
    String? nome,
    String? cognome,
    String? authUserId,
    String? accountEmail,
    int? shirtNumber,
    String? primaryRole,
    List<String>? secondaryRoles,
    String? idConsole,
    String? teamRole,
    VicePermissions? vicePermissions,
  }) {
    return PlayerProfile(
      id: id ?? this.id,
      clubId: clubId ?? this.clubId,
      membershipId: membershipId ?? this.membershipId,
      nome: nome ?? this.nome,
      cognome: cognome ?? this.cognome,
      authUserId: authUserId ?? this.authUserId,
      accountEmail: accountEmail ?? this.accountEmail,
      shirtNumber: shirtNumber ?? this.shirtNumber,
      primaryRole: primaryRole ?? this.primaryRole,
      secondaryRoles: secondaryRoles ?? this.secondaryRoles,
      idConsole: idConsole ?? this.idConsole,
      teamRole: teamRole ?? this.teamRole,
      vicePermissions: vicePermissions ?? this.vicePermissions,
    );
  }

  Map<String, dynamic> toDatabaseMap() {
    final normalizedSecondaryRoles = normalizeRoleCodes(
      secondaryRoles,
    ).where((role) => role != primaryRole).toList();

    return {
      'nome': normalizePlayerName(nome),
      'cognome': normalizePlayerName(cognome),
      'club_id': clubId,
      'membership_id': membershipId,
      'auth_user_id': authUserId,
      'account_email': normalizePlayerAccountEmail(accountEmail),
      'shirt_number': shirtNumber,
      'primary_role': primaryRole,
      'secondary_role': normalizedSecondaryRoles.isEmpty
          ? null
          : normalizedSecondaryRoles.first,
      'secondary_roles': normalizedSecondaryRoles,
      'id_console': idConsole?.trim().isEmpty == true
          ? null
          : idConsole?.trim(),
      'team_role': normalizeTeamRole(teamRole),
    };
  }

  String get fullName => '$nome $cognome'.trim();

  String get accountEmailDisplay => accountEmail ?? '-';

  bool get hasAccountEmail => accountEmail != null && accountEmail!.isNotEmpty;

  bool get hasLinkedAuthAccount => authUserId != null && authUserId!.isNotEmpty;

  bool get canBeClaimedByAuthenticatedUser =>
      !hasLinkedAuthAccount && !hasAccountEmail;

  String get shirtNumberDisplay => shirtNumberLabel(shirtNumber);

  String get primaryRoleDisplay => primaryRole ?? '-';

  String? get secondaryRole =>
      secondaryRoles.isEmpty ? null : secondaryRoles.first;

  String get secondaryRoleDisplay => secondaryRolesDisplay;

  String get secondaryRolesDisplay =>
      secondaryRoles.isEmpty ? '-' : secondaryRoles.join(' / ');

  String get idConsoleDisplay =>
      (idConsole == null || idConsole!.isEmpty) ? '-' : idConsole!;

  bool get hasConsoleId => (idConsole ?? '').trim().isNotEmpty;

  bool get hasPrimaryRole => (primaryRole ?? '').trim().isNotEmpty;

  bool get isProfileSetupComplete =>
      nome.trim().isNotEmpty &&
      cognome.trim().isNotEmpty &&
      hasConsoleId &&
      shirtNumber != null &&
      hasPrimaryRole;

  bool get needsProfileCompletion => !isProfileSetupComplete;

  String get teamRoleDisplay => teamRoleLabel(teamRole);

  bool get isCaptain => teamRole == 'captain';

  bool get isViceCaptain => teamRole == 'vice_captain';

  bool get isManager => isCaptain || isViceCaptain;

  bool get canConfigureVicePermissions => isCaptain;

  bool get canEditTeamRoles => isCaptain;

  bool get canManagePlayers {
    if (isCaptain) return true;
    if (isViceCaptain) return vicePermissions.managePlayers;
    return false;
  }

  bool get canManageLineups {
    if (isCaptain) return true;
    if (isViceCaptain) return vicePermissions.manageLineups;
    return false;
  }

  bool get canManageStreams {
    if (isCaptain) return true;
    if (isViceCaptain) return vicePermissions.manageStreams;
    return false;
  }

  bool get canManageAttendanceAll {
    if (isCaptain) return true;
    if (isViceCaptain) return vicePermissions.manageAttendance;
    return false;
  }

  bool get canManageInvites {
    if (isCaptain) return true;
    if (isViceCaptain) return vicePermissions.manageInvites;
    return false;
  }

  bool get canManageClubInfo {
    if (isCaptain) return true;
    if (isViceCaptain) return vicePermissions.manageClubInfo;
    return false;
  }

  bool get canViewAttendanceDetails => canManageAttendanceAll;

  bool get canCreateOwnProfile => true;

  bool get hasAnyManagementPermission {
    return canManagePlayers ||
        canManageLineups ||
        canManageStreams ||
        canManageAttendanceAll ||
        canManageInvites ||
        canManageClubInfo;
  }

  @Deprecated('Use canManageClubInfo instead.')
  bool get canManageTeamInfo => canManageClubInfo;

  bool canEditPlayer(dynamic targetPlayerId) {
    return canManagePlayers || _sameEntityId(id, targetPlayerId);
  }

  bool isLinkedToAuthUser(String userId) {
    return authUserId == userId;
  }

  bool matchesAccountEmail(String? email) {
    return normalizePlayerAccountEmail(accountEmail) ==
        normalizePlayerAccountEmail(email);
  }

  List<String> get roleCodes {
    return normalizeRoleCodes([primaryRole, ...secondaryRoles]);
  }

  String get roleCodesDisplay =>
      roleCodes.isEmpty ? '-' : roleCodes.join(' / ');

  String get playerListSubtitle =>
      '$fullName • Ruoli: $roleCodesDisplay • Maglia: $shirtNumberDisplay';

  String get lineupSelectionSummary =>
      '$roleCodesDisplay • $idConsoleDisplay • $fullName';

  String? get primaryRoleCategory => roleCategoryLabel(primaryRole);

  String? get secondaryRoleCategory =>
      secondaryRoles.isEmpty ? null : roleCategoryLabel(secondaryRoles.first);

  String get primaryRoleSectionTitle {
    final category = primaryRoleCategory;
    if (category == null) return kUnassignedRoleSectionTitle;

    return kRoleCategorySectionTitles[category] ?? kUnassignedRoleSectionTitle;
  }

  int get primaryRoleSortIndex {
    final role = primaryRole;
    if (role == null) return kPrimaryRoleSortOrder.length;

    final index = kPrimaryRoleSortOrder.indexOf(role);
    return index == -1 ? kPrimaryRoleSortOrder.length : index;
  }

  static bool _sameEntityId(dynamic left, dynamic right) {
    if (left == null || right == null) {
      return false;
    }

    return '$left' == '$right';
  }
}
