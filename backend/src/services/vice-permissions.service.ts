import type { SupabaseClient } from '@supabase/supabase-js';

import type { RequestPrincipal, VicePermissionsRow } from '../domain/types';
import { ForbiddenError } from '../lib/errors';
import { optionalData, requiredData } from '../lib/supabase-result';

function defaultPermissions(clubId: string | number): VicePermissionsRow {
  return {
    club_id: clubId,
    vice_manage_players: false,
    vice_manage_lineups: false,
    vice_manage_streams: false,
    vice_manage_attendance: false,
    vice_manage_invites: false,
    vice_manage_team_info: false,
    updated_at: null,
  };
}

export class VicePermissionsService {
  constructor(private readonly db: SupabaseClient) {}

  async getPermissions(principal: RequestPrincipal): Promise<VicePermissionsRow> {
    const clubId = principal.membership?.club_id;
    if (!clubId) {
      throw new ForbiddenError('Devi appartenere a un club per vedere questi permessi');
    }

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

  async updatePermissions(
    permissions: VicePermissionsRow,
    principal: RequestPrincipal,
  ): Promise<VicePermissionsRow> {
    const clubId = principal.membership?.club_id;
    if (!clubId) {
      throw new ForbiddenError('Devi appartenere a un club per modificare questi permessi');
    }
    if (!principal.isCaptain) {
      throw new ForbiddenError('Solo il capitano puo modificare i permessi dei vice');
    }

    const response = await this.db
      .from('club_permission_settings')
      .upsert(
        {
          ...permissions,
          club_id: clubId,
        },
        { onConflict: 'club_id' },
      )
      .select('*')
      .single();

    return requiredData(response) as VicePermissionsRow;
  }
}
