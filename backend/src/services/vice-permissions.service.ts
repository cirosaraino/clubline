import type { SupabaseClient } from '@supabase/supabase-js';

import type { RequestPrincipal, VicePermissionsRow } from '../domain/types';
import { ForbiddenError } from '../lib/errors';
import { optionalData, requiredData } from '../lib/supabase-result';

export class VicePermissionsService {
  constructor(private readonly db: SupabaseClient) {}

  async getPermissions(): Promise<VicePermissionsRow> {
    const response = await this.db
      .from('team_permission_settings')
      .select('*')
      .eq('id', 1)
      .maybeSingle();

    const permissions = optionalData(response);
    if (!permissions) {
      return this.defaultPermissions();
    }

    return permissions as VicePermissionsRow;
  }

  async updatePermissions(
    permissions: VicePermissionsRow,
    principal: RequestPrincipal,
  ): Promise<VicePermissionsRow> {
    if (!principal.isCaptain) {
      throw new ForbiddenError('Solo il capitano puo modificare i permessi dei vice');
    }

    const response = await this.db
      .from('team_permission_settings')
      .upsert(
        {
          ...permissions,
          id: 1,
        },
        { onConflict: 'id' },
      )
      .select('*')
      .single();

    return requiredData(response) as VicePermissionsRow;
  }

  private defaultPermissions(): VicePermissionsRow {
    return {
      id: 1,
      vice_manage_players: false,
      vice_manage_lineups: false,
      vice_manage_streams: false,
      vice_manage_attendance: false,
      vice_manage_team_info: false,
      updated_at: null,
    };
  }
}
