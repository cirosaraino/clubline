import type { SupabaseClient } from '@supabase/supabase-js';

import type { PlayerProfileRow } from '../domain/types';
import { optionalData, requiredData } from '../lib/supabase-result';

export interface PlayerProfileWritePayload {
  club_id?: string | number | null;
  membership_id?: string | number | null;
  nome?: string;
  cognome?: string;
  auth_user_id?: string | null;
  account_email?: string | null;
  shirt_number?: number | null;
  primary_role?: string | null;
  secondary_role?: string | null;
  secondary_roles?: string[];
  id_console?: string | null;
  team_role?: 'captain' | 'vice_captain' | 'player';
  archived_at?: string | null;
}

export class PlayerProfilesRepository {
  constructor(private readonly db: SupabaseClient) {}

  async listActiveByClubId(clubId: string | number): Promise<PlayerProfileRow[]> {
    const response = await this.db
      .from('player_profiles')
      .select('*')
      .eq('club_id', clubId)
      .is('archived_at', null)
      .order('created_at', { ascending: true });

    return ((optionalData(response) as PlayerProfileRow[] | null) ?? []);
  }

  async findActiveByIdAndClubId(
    playerId: string | number,
    clubId: string | number,
  ): Promise<PlayerProfileRow | null> {
    const response = await this.db
      .from('player_profiles')
      .select('*')
      .eq('id', playerId)
      .eq('club_id', clubId)
      .is('archived_at', null)
      .maybeSingle();

    return optionalData(response) as PlayerProfileRow | null;
  }

  async getActiveByIdAndClubId(
    playerId: string | number,
    clubId: string | number,
  ): Promise<PlayerProfileRow> {
    const response = await this.db
      .from('player_profiles')
      .select('*')
      .eq('id', playerId)
      .eq('club_id', clubId)
      .is('archived_at', null)
      .maybeSingle();

    return requiredData(response, 'Giocatore non trovato') as PlayerProfileRow;
  }

  async findActiveByMembershipId(
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

  async findActiveByAuthUserId(
    authUserId: string,
  ): Promise<PlayerProfileRow | null> {
    const response = await this.db
      .from('player_profiles')
      .select('*')
      .eq('auth_user_id', authUserId)
      .is('archived_at', null)
      .maybeSingle();

    return optionalData(response) as PlayerProfileRow | null;
  }

  async listByAuthUserId(authUserId: string): Promise<PlayerProfileRow[]> {
    const response = await this.db
      .from('player_profiles')
      .select('*')
      .eq('auth_user_id', authUserId);

    return ((optionalData(response) as PlayerProfileRow[] | null) ?? []);
  }

  async findActiveByAccountEmail(
    email: string,
  ): Promise<PlayerProfileRow | null> {
    const response = await this.db
      .from('player_profiles')
      .select('*')
      .eq('account_email', email)
      .is('archived_at', null)
      .maybeSingle();

    return optionalData(response) as PlayerProfileRow | null;
  }

  async findActiveByConsoleId(
    consoleId: string,
  ): Promise<PlayerProfileRow | null> {
    const response = await this.db
      .from('player_profiles')
      .select('*')
      .eq('id_console', consoleId)
      .is('archived_at', null)
      .maybeSingle();

    return optionalData(response) as PlayerProfileRow | null;
  }

  async findActiveByConsoleIdInClub(
    consoleId: string,
    clubId: string | number,
  ): Promise<PlayerProfileRow | null> {
    const response = await this.db
      .from('player_profiles')
      .select('*')
      .eq('club_id', clubId)
      .eq('id_console', consoleId)
      .is('archived_at', null)
      .maybeSingle();

    return optionalData(response) as PlayerProfileRow | null;
  }

  async insert(payload: PlayerProfileWritePayload): Promise<PlayerProfileRow> {
    const response = await this.db
      .from('player_profiles')
      .insert(payload)
      .select('*')
      .single();

    return requiredData(response) as PlayerProfileRow;
  }

  async updateById(
    playerId: string | number,
    payload: PlayerProfileWritePayload,
  ): Promise<PlayerProfileRow> {
    const response = await this.db
      .from('player_profiles')
      .update(payload)
      .eq('id', playerId)
      .select('*')
      .single();

    return requiredData(response) as PlayerProfileRow;
  }

  async updateByIdAndClubId(
    playerId: string | number,
    clubId: string | number,
    payload: PlayerProfileWritePayload,
  ): Promise<PlayerProfileRow> {
    const response = await this.db
      .from('player_profiles')
      .update(payload)
      .eq('id', playerId)
      .eq('club_id', clubId)
      .is('archived_at', null)
      .select('*')
      .single();

    return requiredData(response) as PlayerProfileRow;
  }

  async clearAuthLinksForUser(
    authUserId: string,
    archivedAt: string,
  ): Promise<void> {
    const profiles = await this.listByAuthUserId(authUserId);

    for (const profile of profiles) {
      const response = await this.db
        .from('player_profiles')
        .update({
          auth_user_id: null,
          account_email: null,
          archived_at: profile.archived_at ?? archivedAt,
        })
        .eq('id', profile.id);

      if (response.error) {
        throw response.error;
      }
    }
  }
}
