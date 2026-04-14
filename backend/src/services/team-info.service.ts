import type { SupabaseClient } from '@supabase/supabase-js';

import type { RequestPrincipal, TeamInfoRow } from '../domain/types';
import { ForbiddenError } from '../lib/errors';
import { optionalData, requiredData } from '../lib/supabase-result';

export class TeamInfoService {
  constructor(private readonly db: SupabaseClient) {}

  async getTeamInfo(): Promise<TeamInfoRow> {
    const response = await this.db
      .from('team_settings')
      .select('*')
      .eq('id', 1)
      .maybeSingle();

    const teamInfo = optionalData(response);
    if (!teamInfo) {
      return this.defaultTeamInfo();
    }

    return teamInfo as TeamInfoRow;
  }

  async updateTeamInfo(teamInfo: TeamInfoRow, principal: RequestPrincipal): Promise<TeamInfoRow> {
    if (!principal.canManageTeamInfo) {
      throw new ForbiddenError('Non puoi modificare le info squadra');
    }

    const { updated_at, ...payload } = teamInfo;

    const response = await this.db
      .from('team_settings')
      .upsert(
        {
          ...payload,
          id: 1,
        },
        { onConflict: 'id' },
      )
      .select('*')
      .single();

    return requiredData(response) as TeamInfoRow;
  }

  private defaultTeamInfo(): TeamInfoRow {
    return {
      id: 1,
      team_name: 'Ultras Mentality',
      crest_url: null,
      website_url: null,
      youtube_url: null,
      discord_url: null,
      facebook_url: null,
      instagram_url: null,
      twitch_url: null,
      tiktok_url: null,
      additional_links: [],
      updated_at: null,
    };
  }
}
