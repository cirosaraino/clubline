import type { SupabaseClient } from '@supabase/supabase-js';

import { buildPrincipal } from '../domain/access';
import type {
  AuthUserDto,
  PlayerProfileRow,
  RequestPrincipal,
  VicePermissionsRow,
} from '../domain/types';
import { NotFoundError } from '../lib/errors';
import { optionalData, requiredData } from '../lib/supabase-result';

function normalizeEmail(email: string | null | undefined): string | null {
  const normalized = email?.trim().toLowerCase() ?? '';
  return normalized.length > 0 ? normalized : null;
}

export class AccessService {
  constructor(private readonly db: SupabaseClient) {}

  async resolvePrincipal(authUser: AuthUserDto): Promise<RequestPrincipal> {
    let player = await this.findPlayerByAuthUserId(authUser.id);

    if (!player && authUser.email) {
      player = await this.claimPlayerByEmailIfPossible(authUser);
    }

    const [permissions, canBootstrapCaptain] = await Promise.all([
      this.loadVicePermissions(),
      this.canBootstrapCaptain(),
    ]);

    return buildPrincipal(authUser, player, permissions, canBootstrapCaptain);
  }

  async loadCurrentPlayer(authUserId: string): Promise<PlayerProfileRow | null> {
    return this.findPlayerByAuthUserId(authUserId);
  }

  async loadVicePermissions(): Promise<VicePermissionsRow> {
    const response = await this.db
      .from('team_permission_settings')
      .select('*')
      .eq('id', 1)
      .maybeSingle();

    const permissions = optionalData(response);
    if (!permissions) {
      return {
        id: 1,
        vice_manage_players: false,
        vice_manage_lineups: false,
        vice_manage_streams: false,
        vice_manage_attendance: false,
        vice_manage_team_info: false,
      };
    }

    return permissions as VicePermissionsRow;
  }

  async canBootstrapCaptain(): Promise<boolean> {
    const response = await this.db
      .from('player_profiles')
      .select('id')
      .not('auth_user_id', 'is', null)
      .limit(1)
      .maybeSingle();

    return optionalData(response) == null;
  }

  async hasLinkedAuthAccount(): Promise<boolean> {
    const response = await this.db
      .from('player_profiles')
      .select('id')
      .not('auth_user_id', 'is', null)
      .limit(1)
      .maybeSingle();

    return optionalData(response) != null;
  }

  async getPlayerById(playerId: string | number): Promise<PlayerProfileRow> {
    const response = await this.db
      .from('player_profiles')
      .select('*')
      .eq('id', playerId)
      .maybeSingle();

    return requiredData(response, 'Giocatore non trovato') as PlayerProfileRow;
  }

  async findPlayerByConsoleId(consoleId: string): Promise<PlayerProfileRow | null> {
    const normalized = consoleId.trim();
    if (!normalized) {
      return null;
    }

    const response = await this.db
      .from('player_profiles')
      .select('*')
      .eq('id_console', normalized)
      .maybeSingle();

    return optionalData(response) as PlayerProfileRow | null;
  }

  async getCurrentPlayerOrNull(authUserId: string): Promise<PlayerProfileRow | null> {
    return this.findPlayerByAuthUserId(authUserId);
  }

  async ensureCurrentPlayer(authUser: AuthUserDto): Promise<PlayerProfileRow | null> {
    return this.claimPlayerByEmailIfPossible(authUser);
  }

  private async findPlayerByAuthUserId(authUserId: string): Promise<PlayerProfileRow | null> {
    const response = await this.db
      .from('player_profiles')
      .select('*')
      .eq('auth_user_id', authUserId)
      .maybeSingle();

    return optionalData(response) as PlayerProfileRow | null;
  }

  private async claimPlayerByEmailIfPossible(authUser: AuthUserDto): Promise<PlayerProfileRow | null> {
    const email = normalizeEmail(authUser.email);
    if (!email) {
      return null;
    }

    const response = await this.db
      .from('player_profiles')
      .select('*')
      .eq('account_email', email)
      .maybeSingle();

    const player = optionalData(response) as PlayerProfileRow | null;
    if (!player) {
      return null;
    }

    if (player.auth_user_id && player.auth_user_id !== authUser.id) {
      return player;
    }

    if (!player.auth_user_id) {
      const updateResponse = await this.db
        .from('player_profiles')
        .update({
          auth_user_id: authUser.id,
          account_email: email,
        })
        .eq('id', player.id)
        .select('*')
        .single();

      return requiredData(updateResponse) as PlayerProfileRow;
    }

    return player;
  }
}
