import type { SupabaseClient } from '@supabase/supabase-js';

import { buildPrincipal } from '../domain/access';
import type {
  AuthUserDto,
  ClubRow,
  MembershipRow,
  PlayerProfileRow,
  RequestPrincipal,
  TeamInfoRow,
  VicePermissionsRow,
} from '../domain/types';
import { NotFoundError } from '../lib/errors';
import { optionalData, requiredData } from '../lib/supabase-result';

function normalizeEmail(email: string | null | undefined): string | null {
  const normalized = email?.trim().toLowerCase() ?? '';
  return normalized.length > 0 ? normalized : null;
}

function defaultPermissions(clubId: string | number): VicePermissionsRow {
  return {
    club_id: clubId,
    vice_manage_players: false,
    vice_manage_lineups: false,
    vice_manage_streams: false,
    vice_manage_attendance: false,
    vice_manage_team_info: false,
  };
}

export class AccessService {
  constructor(private readonly db: SupabaseClient) {}

  async resolvePrincipal(authUser: AuthUserDto): Promise<RequestPrincipal> {
    const membership = await this.findActiveMembershipByUserId(authUser.id);
    const club = membership ? await this.getClubById(membership.club_id) : null;
    const player = membership
      ? await this.findActivePlayerForMembership(membership.id)
      : await this.findLegacyPlayerByAuthUserId(authUser.id);
    const permissions = membership
      ? await this.loadVicePermissions(membership.club_id)
      : defaultPermissions(0);

    return buildPrincipal(authUser, membership, club, player, permissions);
  }

  async loadCurrentPlayer(authUserId: string): Promise<PlayerProfileRow | null> {
    const membership = await this.findActiveMembershipByUserId(authUserId);
    if (membership) {
      return this.findActivePlayerForMembership(membership.id);
    }

    return this.findLegacyPlayerByAuthUserId(authUserId);
  }

  async loadCurrentMembership(authUserId: string): Promise<MembershipRow | null> {
    return this.findActiveMembershipByUserId(authUserId);
  }

  async loadVicePermissions(clubId: string | number): Promise<VicePermissionsRow> {
    const response = await this.db
      .from('club_permission_settings')
      .select('*')
      .eq('club_id', clubId)
      .maybeSingle();

    const permissions = optionalData(response);
    if (!permissions) {
      return defaultPermissions(clubId);
    }

    return permissions as VicePermissionsRow;
  }

  async getClubById(clubId: string | number): Promise<ClubRow> {
    const response = await this.db
      .from('clubs')
      .select('*')
      .eq('id', clubId)
      .maybeSingle();

    return requiredData(response, 'Club non trovato') as ClubRow;
  }

  async getCurrentClubOrNull(authUserId: string): Promise<ClubRow | null> {
    const membership = await this.findActiveMembershipByUserId(authUserId);
    if (!membership) {
      return null;
    }

    return this.getClubById(membership.club_id);
  }

  async getTeamInfoForClub(clubId: string | number): Promise<TeamInfoRow> {
    const [club, settings] = await Promise.all([
      this.getClubById(clubId),
      this.getClubSettingsOrNull(clubId),
    ]);

    return {
      id: club.id,
      team_name: club.name,
      crest_url: club.logo_url,
      website_url: settings?.website_url ?? null,
      youtube_url: settings?.youtube_url ?? null,
      discord_url: settings?.discord_url ?? null,
      facebook_url: settings?.facebook_url ?? null,
      instagram_url: settings?.instagram_url ?? null,
      twitch_url: settings?.twitch_url ?? null,
      tiktok_url: settings?.tiktok_url ?? null,
      additional_links: settings?.additional_links ?? [],
      primary_color: club.primary_color,
      accent_color: club.accent_color,
      surface_color: club.surface_color,
      slug: club.slug,
      updated_at: settings?.updated_at ?? club.updated_at ?? null,
    };
  }

  async getPlayerById(
    playerId: string | number,
    clubId?: string | number,
  ): Promise<PlayerProfileRow> {
    let query = this.db
      .from('player_profiles')
      .select('*')
      .eq('id', playerId)
      .is('archived_at', null);

    if (clubId != null) {
      query = query.eq('club_id', clubId);
    }

    const response = await query.maybeSingle();
    return requiredData(response, 'Giocatore non trovato') as PlayerProfileRow;
  }

  async findPlayerByConsoleId(
    consoleId: string,
    clubId: string | number,
  ): Promise<PlayerProfileRow | null> {
    const normalized = consoleId.trim();
    if (!normalized) {
      return null;
    }

    const response = await this.db
      .from('player_profiles')
      .select('*')
      .eq('club_id', clubId)
      .eq('id_console', normalized)
      .is('archived_at', null)
      .maybeSingle();

    return optionalData(response) as PlayerProfileRow | null;
  }

  async getCurrentPlayerOrNull(authUserId: string): Promise<PlayerProfileRow | null> {
    return this.loadCurrentPlayer(authUserId);
  }

  async ensureCurrentPlayer(authUser: AuthUserDto): Promise<PlayerProfileRow | null> {
    const membership = await this.findActiveMembershipByUserId(authUser.id);
    if (!membership) {
      return null;
    }

    const existing = await this.findActivePlayerForMembership(membership.id);
    if (existing) {
      return existing;
    }

    const email = normalizeEmail(authUser.email);
    if (!email) {
      return null;
    }

    const response = await this.db
      .from('player_profiles')
      .select('*')
      .eq('club_id', membership.club_id)
      .eq('account_email', email)
      .is('archived_at', null)
      .maybeSingle();

    const matchedPlayer = optionalData(response) as PlayerProfileRow | null;
    if (!matchedPlayer) {
      return null;
    }

    const updateResponse = await this.db
      .from('player_profiles')
      .update({
        membership_id: membership.id,
        auth_user_id: authUser.id,
        account_email: email,
      })
      .eq('id', matchedPlayer.id)
      .select('*')
      .single();

    return requiredData(updateResponse) as PlayerProfileRow;
  }

  async ensureCaptainMembership(principal: RequestPrincipal): Promise<MembershipRow> {
    const membership = principal.membership;
    if (!membership) {
      throw new NotFoundError('Membership non trovata');
    }

    return membership;
  }

  async hasLinkedAuthAccount(): Promise<boolean> {
    const response = await this.db
      .from('memberships')
      .select('id')
      .eq('status', 'active')
      .limit(1)
      .maybeSingle();

    return optionalData(response) != null;
  }

  async listClubMembers(clubId: string | number): Promise<MembershipRow[]> {
    const response = await this.db
      .from('memberships')
      .select('*')
      .eq('club_id', clubId)
      .eq('status', 'active')
      .order('created_at', { ascending: true });

    return ((optionalData(response) as MembershipRow[] | null) ?? []);
  }

  private async getClubSettingsOrNull(
    clubId: string | number,
  ): Promise<{
    website_url: string | null;
    youtube_url: string | null;
    discord_url: string | null;
    facebook_url: string | null;
    instagram_url: string | null;
    twitch_url: string | null;
    tiktok_url: string | null;
    additional_links: Array<{ label: string; url: string }>;
    updated_at?: string | null;
  } | null> {
    const response = await this.db
      .from('club_settings')
      .select('*')
      .eq('club_id', clubId)
      .maybeSingle();

    return optionalData(response) as {
      website_url: string | null;
      youtube_url: string | null;
      discord_url: string | null;
      facebook_url: string | null;
      instagram_url: string | null;
      twitch_url: string | null;
      tiktok_url: string | null;
      additional_links: Array<{ label: string; url: string }>;
      updated_at?: string | null;
    } | null;
  }

  private async findActiveMembershipByUserId(authUserId: string): Promise<MembershipRow | null> {
    const response = await this.db
      .from('memberships')
      .select('*')
      .eq('auth_user_id', authUserId)
      .eq('status', 'active')
      .maybeSingle();

    return optionalData(response) as MembershipRow | null;
  }

  private async findActivePlayerForMembership(
    membershipId: string | number,
  ): Promise<PlayerProfileRow | null> {
    const response = await this.db
      .from('player_profiles')
      .select('*')
      .eq('membership_id', membershipId)
      .is('archived_at', null)
      .maybeSingle();

    return optionalData(response) as PlayerProfileRow | null;
  }

  private async findLegacyPlayerByAuthUserId(authUserId: string): Promise<PlayerProfileRow | null> {
    const response = await this.db
      .from('player_profiles')
      .select('*')
      .eq('auth_user_id', authUserId)
      .is('archived_at', null)
      .maybeSingle();

    return optionalData(response) as PlayerProfileRow | null;
  }
}
