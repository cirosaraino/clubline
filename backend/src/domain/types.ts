import type { Request } from 'express';

export type TeamRole = 'captain' | 'vice_captain' | 'player';
export type MembershipStatus = 'active' | 'left';
export type RequestStatus = 'pending' | 'approved' | 'rejected' | 'cancelled' | 'expired';
export type StreamStatus = 'live' | 'scheduled' | 'ended' | 'unknown';
export type ClubInviteStatus = 'pending' | 'accepted' | 'declined' | 'revoked' | 'expired';
export type AppNotificationType =
  | 'club_invite_received'
  | 'club_invite_accepted'
  | 'club_invite_declined'
  | 'club_invite_revoked'
  | 'lineup_published'
  | 'attendance_published';

export interface AuthUserDto {
  id: string;
  email: string | null;
  emailVerified: boolean;
  emailVerifiedAt: string | null;
}

export interface AuthSessionDto {
  accessToken: string;
  refreshToken: string;
  expiresAt: string;
  user: AuthUserDto;
}

export interface PlayerProfileRow {
  id: number | string;
  club_id: number | string | null;
  membership_id: number | string | null;
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
  archived_at?: string | null;
  created_at?: string | null;
  updated_at?: string | null;
}

export interface ClubCustomLinkRow {
  label: string;
  url: string;
}

export interface ClubRow {
  id: number | string;
  name: string;
  normalized_name: string;
  slug: string;
  logo_url: string | null;
  logo_storage_path: string | null;
  primary_color: string | null;
  accent_color: string | null;
  surface_color: string | null;
  created_by_user_id: string | null;
  created_at?: string | null;
  updated_at?: string | null;
}

export interface ClubSettingsRow {
  club_id: number | string;
  website_url: string | null;
  youtube_url: string | null;
  discord_url: string | null;
  facebook_url: string | null;
  instagram_url: string | null;
  twitch_url: string | null;
  tiktok_url: string | null;
  additional_links: ClubCustomLinkRow[];
  updated_at?: string | null;
}

export interface ClubInfoRow {
  id: number | string;
  club_name: string;
  crest_url: string | null;
  crest_storage_path: string | null;
  website_url: string | null;
  youtube_url: string | null;
  discord_url: string | null;
  facebook_url: string | null;
  instagram_url: string | null;
  twitch_url: string | null;
  tiktok_url: string | null;
  additional_links: ClubCustomLinkRow[];
  primary_color: string | null;
  accent_color: string | null;
  surface_color: string | null;
  slug: string | null;
  updated_at?: string | null;
}

export interface VicePermissionsRow {
  club_id: number | string;
  vice_manage_players: boolean;
  vice_manage_lineups: boolean;
  vice_manage_streams: boolean;
  vice_manage_attendance: boolean;
  vice_manage_invites: boolean;
  vice_manage_team_info: boolean;
  updated_at?: string | null;
}

export interface MembershipRow {
  id: number | string;
  club_id: number | string;
  auth_user_id: string;
  role: TeamRole;
  status: MembershipStatus;
  left_at: string | null;
  created_at?: string | null;
  updated_at?: string | null;
  club?: ClubRow | null;
}

export interface JoinRequestRow {
  id: number | string;
  club_id: number | string;
  requester_user_id: string;
  requester_email: string | null;
  requested_nome: string;
  requested_cognome: string;
  requested_shirt_number: number | null;
  requested_primary_role: string | null;
  status: RequestStatus;
  decided_by_membership_id: number | string | null;
  decided_at: string | null;
  cancelled_at: string | null;
  expires_at: string | null;
  created_at?: string | null;
  updated_at?: string | null;
  club?: ClubRow | null;
}

export interface LeaveRequestRow {
  id: number | string;
  club_id: number | string;
  membership_id: number | string;
  requested_by_user_id: string;
  status: RequestStatus;
  decided_by_membership_id: number | string | null;
  decided_at: string | null;
  cancelled_at: string | null;
  expires_at: string | null;
  created_at?: string | null;
  updated_at?: string | null;
  membership?: MembershipRow | null;
}

export interface ClubInviteRow {
  id: number | string;
  club_id: number | string;
  created_by_user_id: string | null;
  created_by_membership_id: number | string | null;
  target_user_id: string;
  target_player_profile_id: number | string | null;
  target_account_email: string | null;
  target_nome: string;
  target_cognome: string;
  target_id_console: string | null;
  target_primary_role: string | null;
  status: ClubInviteStatus;
  resolved_at: string | null;
  resolved_by_user_id: string | null;
  resolved_by_membership_id: number | string | null;
  accepted_membership_id: number | string | null;
  accepted_player_id: number | string | null;
  created_at?: string | null;
  updated_at?: string | null;
  club?: ClubRow | null;
}

export type InviteCandidateReason =
  | 'pending_join_request_same_club'
  | 'pending_join_request_other_club';

export interface InviteCandidateDto {
  user_id: string;
  player_profile_id: number | string;
  nome: string;
  cognome: string;
  account_email: string | null;
  id_console: string | null;
  primary_role: string | null;
  invitable: boolean;
  reason: InviteCandidateReason | null;
}

export interface AppNotificationRow {
  id: number | string;
  recipient_user_id: string;
  club_id: number | string | null;
  notification_type: AppNotificationType;
  title: string;
  body: string | null;
  metadata: Record<string, unknown>;
  related_invite_id: number | string | null;
  read_at: string | null;
  dedupe_key: string | null;
  created_at?: string | null;
}

export interface CursorPaginationDto {
  limit: number;
  hasMore: boolean;
  nextCursor: string | null;
}

export interface ClubInviteListResultDto {
  invites: ClubInviteRow[];
  pagination: CursorPaginationDto;
}

export interface AppNotificationsListResultDto {
  notifications: AppNotificationRow[];
  unreadCount: number;
  pagination: CursorPaginationDto;
}

export interface StreamLinkRow {
  id: number | string;
  club_id: number | string;
  stream_title: string;
  competition_name: string | null;
  played_on: string;
  stream_url: string;
  stream_status: StreamStatus;
  stream_ended_at: string | null;
  provider: string | null;
  result: string | null;
  created_at?: string | null;
}

export interface StreamMetadataDto {
  title: string;
  normalizedUrl: string;
  status: StreamStatus;
  provider: string;
  suggestedPlayedOn: string;
  endedAt: string | null;
}

export interface LineupRow {
  id: number | string;
  club_id: number | string;
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
  club_id?: number | string | null;
  player_id: number | string;
  position_code: string;
  created_at?: string | null;
  player_profiles?: PlayerProfileRow | null;
}

export interface AttendanceWeekRow {
  id: number | string;
  club_id: number | string;
  week_start: string;
  week_end: string;
  selected_dates: string[];
  archived_at: string | null;
  created_at?: string | null;
}

export interface AttendanceEntryRow {
  id: number | string;
  club_id: number | string;
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
  club: ClubRow | null;
  membership: MembershipRow | null;
  player: PlayerProfileRow | null;
  permissions: VicePermissionsRow;
  isCaptain: boolean;
  isViceCaptain: boolean;
  hasClub: boolean;
  canManagePlayers: boolean;
  canManageLineups: boolean;
  canManageStreams: boolean;
  canManageAttendance: boolean;
  canManageInvites: boolean;
  canManageClubInfo: boolean;
}

export interface AuthenticatedRequest extends Request {
  principal?: RequestPrincipal;
}
