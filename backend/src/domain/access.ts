import type {
  AuthUserDto,
  ClubRow,
  MembershipRow,
  PlayerProfileRow,
  RequestPrincipal,
  VicePermissionsRow,
} from './types';

export function buildPrincipal(
  authUser: AuthUserDto,
  membership: MembershipRow | null,
  club: ClubRow | null,
  player: PlayerProfileRow | null,
  permissions: VicePermissionsRow,
): RequestPrincipal {
  const effectiveRole = membership?.role ?? player?.team_role ?? 'player';
  const isCaptain = effectiveRole === 'captain';
  const isViceCaptain = effectiveRole === 'vice_captain';
  const hasClub = membership != null && club != null;

  return {
    authUser,
    membership,
    club,
    player,
    permissions,
    isCaptain,
    isViceCaptain,
    hasClub,
    canManagePlayers: isCaptain || (isViceCaptain && permissions.vice_manage_players),
    canManageLineups: isCaptain || (isViceCaptain && permissions.vice_manage_lineups),
    canManageStreams: isCaptain || (isViceCaptain && permissions.vice_manage_streams),
    canManageAttendance: isCaptain || (isViceCaptain && permissions.vice_manage_attendance),
    canManageClubInfo:
      isCaptain || (isViceCaptain && permissions.vice_manage_team_info),
  };
}
