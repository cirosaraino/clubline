import type { Request } from 'express';

export type TeamRole = 'captain' | 'vice_captain' | 'player';

export interface AuthUserDto {
  id: string;
  email: string | null;
}

export interface AuthSessionDto {
  accessToken: string;
  refreshToken: string;
  expiresAt: string;
  user: AuthUserDto;
}

export interface PlayerProfileRow {
  id: number | string;
  nome: string;
  cognome: string;
  auth_user_id: string | null;
  account_email: string | null;
  shirt_number: number | null;
  primary_role: string | null;
  secondary_role: string | null;
  secondary_roles: string[];
  id_console: string | null;
  team_role: TeamRole;
  created_at?: string | null;
  updated_at?: string | null;
}

export interface TeamCustomLinkRow {
  label: string;
  url: string;
}

export interface TeamInfoRow {
  id: number;
  team_name: string;
  crest_url: string | null;
  website_url: string | null;
  youtube_url: string | null;
  discord_url: string | null;
  facebook_url: string | null;
  instagram_url: string | null;
  twitch_url: string | null;
  tiktok_url: string | null;
  additional_links: TeamCustomLinkRow[];
  updated_at?: string | null;
}

export interface VicePermissionsRow {
  id: number;
  vice_manage_players: boolean;
  vice_manage_lineups: boolean;
  vice_manage_streams: boolean;
  vice_manage_attendance: boolean;
  vice_manage_team_info: boolean;
  updated_at?: string | null;
}

export interface StreamLinkRow {
  id: number | string;
  stream_title: string;
  competition_name: string | null;
  played_on: string;
  stream_url: string;
  stream_status: 'live' | 'ended';
  stream_ended_at: string | null;
  provider: string | null;
  result: string | null;
  created_at?: string | null;
}

export interface StreamMetadataDto {
  title: string;
  normalizedUrl: string;
  status: 'live' | 'ended';
  provider: string;
  suggestedPlayedOn: string;
  endedAt: string | null;
}

export interface LineupRow {
  id: number | string;
  competition_name: string;
  match_datetime: string;
  opponent_name: string | null;
  formation_module: string;
  notes: string | null;
  created_at?: string | null;
}

export interface LineupPlayerRow {
  id: number | string;
  lineup_id: number | string;
  player_id: number | string;
  position_code: string;
  created_at?: string | null;
  player_profiles?: PlayerProfileRow | null;
}

export interface AttendanceWeekRow {
  id: number | string;
  week_start: string;
  week_end: string;
  selected_dates: string[];
  archived_at: string | null;
  created_at?: string | null;
}

export interface AttendanceEntryRow {
  id: number | string;
  week_id: number | string;
  player_id: number | string;
  attendance_date: string;
  availability: 'pending' | 'yes' | 'no';
  updated_by_player_id: number | string | null;
  updated_at?: string | null;
  created_at?: string | null;
  player?: PlayerProfileRow | null;
}

export interface AttendanceLineupFiltersDto {
  absentPlayerIds: Array<number | string>;
  pendingPlayerIds: Array<number | string>;
}

export interface RequestPrincipal {
  authUser: AuthUserDto;
  player: PlayerProfileRow | null;
  permissions: VicePermissionsRow;
  canBootstrapCaptain: boolean;
  isCaptain: boolean;
  isViceCaptain: boolean;
  canManagePlayers: boolean;
  canManageLineups: boolean;
  canManageStreams: boolean;
  canManageAttendance: boolean;
  canManageTeamInfo: boolean;
}

export interface AuthenticatedRequest extends Request {
  principal?: RequestPrincipal;
}
