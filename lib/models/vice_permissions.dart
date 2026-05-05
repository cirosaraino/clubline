class VicePermissions {
  const VicePermissions({
    this.managePlayers = false,
    this.manageLineups = false,
    this.manageStreams = false,
    this.manageAttendance = false,
    this.manageInvites = false,
    this.manageClubInfo = false,
  });

  static const defaults = VicePermissions();
  static const fullAccess = VicePermissions(
    managePlayers: true,
    manageLineups: true,
    manageStreams: true,
    manageAttendance: true,
    manageInvites: true,
    manageClubInfo: true,
  );

  final bool managePlayers;
  final bool manageLineups;
  final bool manageStreams;
  final bool manageAttendance;
  final bool manageInvites;
  final bool manageClubInfo;

  factory VicePermissions.fromMap(Map<String, dynamic> map) {
    return VicePermissions(
      managePlayers: map['vice_manage_players'] == true,
      manageLineups: map['vice_manage_lineups'] == true,
      manageStreams: map['vice_manage_streams'] == true,
      manageAttendance: map['vice_manage_attendance'] == true,
      manageInvites: map['vice_manage_invites'] == true,
      manageClubInfo: map['vice_manage_team_info'] == true,
    );
  }

  VicePermissions copyWith({
    bool? managePlayers,
    bool? manageLineups,
    bool? manageStreams,
    bool? manageAttendance,
    bool? manageInvites,
    bool? manageClubInfo,
  }) {
    return VicePermissions(
      managePlayers: managePlayers ?? this.managePlayers,
      manageLineups: manageLineups ?? this.manageLineups,
      manageStreams: manageStreams ?? this.manageStreams,
      manageAttendance: manageAttendance ?? this.manageAttendance,
      manageInvites: manageInvites ?? this.manageInvites,
      manageClubInfo: manageClubInfo ?? this.manageClubInfo,
    );
  }

  Map<String, dynamic> toDatabaseMap() {
    return {
      'vice_manage_players': managePlayers,
      'vice_manage_lineups': manageLineups,
      'vice_manage_streams': manageStreams,
      'vice_manage_attendance': manageAttendance,
      'vice_manage_invites': manageInvites,
      'vice_manage_team_info': manageClubInfo,
    };
  }

  bool get hasAnyEnabledPermission {
    return managePlayers ||
        manageLineups ||
        manageStreams ||
        manageAttendance ||
        manageInvites ||
        manageClubInfo;
  }

  bool get isFullAccess {
    return managePlayers &&
        manageLineups &&
        manageStreams &&
        manageAttendance &&
        manageInvites &&
        manageClubInfo;
  }

  @Deprecated('Use manageClubInfo instead.')
  bool get manageTeamInfo => manageClubInfo;
}
