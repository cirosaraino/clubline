import type { SupabaseClient } from '@supabase/supabase-js';

import type {
  LineupPlayerRow,
  LineupRow,
  RequestPrincipal,
} from '../domain/types';
import { ForbiddenError } from '../lib/errors';
import { ensureSuccess, optionalData, requiredData } from '../lib/supabase-result';

export interface LineupInput {
  competition_name: string;
  match_datetime: string;
  opponent_name?: string | null;
  formation_module: string;
  notes?: string | null;
}

export interface LineupAssignmentInput {
  player_id: number | string;
  position_code: string;
}

function normalizeText(value: string | null | undefined): string | null {
  const normalized = value?.trim() ?? '';
  return normalized.length > 0 ? normalized : null;
}

export class LineupsService {
  constructor(private readonly db: SupabaseClient) {}

  async listLineups(): Promise<LineupRow[]> {
    const response = await this.db
      .from('lineups')
      .select('*')
      .order('match_datetime', { ascending: true });

    return ((optionalData(response) as LineupRow[] | null) ?? []);
  }

  async createLineup(input: LineupInput, principal: RequestPrincipal): Promise<LineupRow> {
    this.ensureCanManageLineups(principal);

    const response = await this.db
      .from('lineups')
      .insert(this.buildPayload(input))
      .select('*')
      .single();

    return requiredData(response) as LineupRow;
  }

  async updateLineup(
    lineupId: string | number,
    input: LineupInput,
    principal: RequestPrincipal,
  ): Promise<LineupRow> {
    this.ensureCanManageLineups(principal);

    const response = await this.db
      .from('lineups')
      .update(this.buildPayload(input))
      .eq('id', lineupId)
      .select('*')
      .single();

    return requiredData(response) as LineupRow;
  }

  async deleteLineup(lineupId: string | number, principal: RequestPrincipal): Promise<void> {
    this.ensureCanManageLineups(principal);
    const response = await this.db.from('lineups').delete().eq('id', lineupId);
    ensureSuccess(response);
  }

  async listLineupPlayers(lineupId: string | number): Promise<LineupPlayerRow[]> {
    const response = await this.db
      .from('lineup_players')
      .select('id, lineup_id, player_id, position_code, player_profiles(*)')
      .eq('lineup_id', lineupId);

    return ((optionalData(response) as LineupPlayerRow[] | null) ?? []);
  }

  async listAssignmentsForLineups(
    lineupIds: Array<string | number>,
  ): Promise<LineupPlayerRow[]> {
    if (lineupIds.length === 0) {
      return [];
    }

    const response = await this.db
      .from('lineup_players')
      .select('id, lineup_id, player_id, position_code, player_profiles(*)')
      .in('lineup_id', lineupIds);

    return ((optionalData(response) as LineupPlayerRow[] | null) ?? []);
  }

  async replaceLineupPlayers(
    lineupId: string | number,
    assignments: LineupAssignmentInput[],
    principal: RequestPrincipal,
  ): Promise<void> {
    this.ensureCanManageLineups(principal);

    const deleteResponse = await this.db
      .from('lineup_players')
      .delete()
      .eq('lineup_id', lineupId);
    ensureSuccess(deleteResponse);

    if (assignments.length === 0) {
      return;
    }

    const insertResponse = await this.db.from('lineup_players').insert(
      assignments.map((assignment) => ({
        lineup_id: lineupId,
        player_id: assignment.player_id,
        position_code: assignment.position_code.trim(),
      })),
    );

    ensureSuccess(insertResponse);
  }

  private ensureCanManageLineups(principal: RequestPrincipal): void {
    if (!principal.canManageLineups) {
      throw new ForbiddenError('Non hai i permessi per gestire le formazioni');
    }
  }

  private buildPayload(input: LineupInput) {
    return {
      competition_name: input.competition_name.trim(),
      match_datetime: new Date(input.match_datetime).toISOString(),
      opponent_name: normalizeText(input.opponent_name),
      formation_module: input.formation_module.trim(),
      notes: normalizeText(input.notes),
    };
  }
}
