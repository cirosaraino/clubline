import type {
  PlayerProfileRow,
  RequestPrincipal,
  VicePermissionsRow,
} from './types';

export function buildPrincipal(
  authUser: { id: string; email: string | null },
  player: PlayerProfileRow | null,
  permissions: VicePermissionsRow,
  canBootstrapCaptain: boolean,
): RequestPrincipal {
  const isCaptain = player?.team_role === 'captain';
  const isViceCaptain = player?.team_role === 'vice_captain';

  return {
    authUser,
    player,
    permissions,
    canBootstrapCaptain,
    isCaptain,
    isViceCaptain,
    canManagePlayers: isCaptain || (isViceCaptain && permissions.vice_manage_players),
    canManageLineups: isCaptain || (isViceCaptain && permissions.vice_manage_lineups),
    canManageStreams: isCaptain || (isViceCaptain && permissions.vice_manage_streams),
    canManageAttendance: isCaptain || (isViceCaptain && permissions.vice_manage_attendance),
    canManageTeamInfo: isCaptain || (isViceCaptain && permissions.vice_manage_team_info),
  };
}
