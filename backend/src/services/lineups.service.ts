import type { SupabaseClient } from '@supabase/supabase-js';

import type {
  LineupPlayerRow,
  LineupRow,
  RequestPrincipal,
} from '../domain/types';
import { ForbiddenError, NotFoundError } from '../lib/errors';
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

  async listLineups(principal: RequestPrincipal): Promise<LineupRow[]> {
    const clubId = this.requireClubId(principal);
    const response = await this.db
      .from('lineups')
      .select('*')
      .eq('club_id', clubId)
      .order('match_datetime', { ascending: true });

    return ((optionalData(response) as LineupRow[] | null) ?? []);
  }

  async createLineup(input: LineupInput, principal: RequestPrincipal): Promise<LineupRow> {
    const clubId = this.requireClubId(principal);
    this.ensureCanManageLineups(principal);

    const response = await this.db
      .from('lineups')
      .insert({
        ...this.buildPayload(input),
        club_id: clubId,
      })
      .select('*')
      .single();

    return requiredData(response) as LineupRow;
  }

  async updateLineup(
    lineupId: string | number,
    input: LineupInput,
    principal: RequestPrincipal,
  ): Promise<LineupRow> {
    const clubId = this.requireClubId(principal);
    this.ensureCanManageLineups(principal);
    await this.getLineupOrThrow(lineupId, clubId);

    const response = await this.db
      .from('lineups')
      .update(this.buildPayload(input))
      .eq('id', lineupId)
      .eq('club_id', clubId)
      .select('*')
      .single();

    return requiredData(response) as LineupRow;
  }

  async deleteLineup(lineupId: string | number, principal: RequestPrincipal): Promise<void> {
    const clubId = this.requireClubId(principal);
    this.ensureCanManageLineups(principal);
    const response = await this.db
      .from('lineups')
      .delete()
      .eq('id', lineupId)
      .eq('club_id', clubId);
    ensureSuccess(response);
  }

  async deleteAllLineups(principal: RequestPrincipal): Promise<void> {
    const clubId = this.requireClubId(principal);
    this.ensureCanManageLineups(principal);

    const response = await this.db
      .from('lineups')
      .delete()
      .eq('club_id', clubId);
    ensureSuccess(response);
  }

  async deleteLineupsByIds(
    lineupIds: Array<string | number>,
    principal: RequestPrincipal,
  ): Promise<void> {
    const clubId = this.requireClubId(principal);
    this.ensureCanManageLineups(principal);

    if (lineupIds.length === 0) {
      return;
    }

    const response = await this.db
      .from('lineups')
      .delete()
      .eq('club_id', clubId)
      .in('id', lineupIds);
    ensureSuccess(response);
  }

  async listLineupPlayers(
    lineupId: string | number,
    principal: RequestPrincipal,
  ): Promise<LineupPlayerRow[]> {
    const clubId = this.requireClubId(principal);
    await this.getLineupOrThrow(lineupId, clubId);

    const response = await this.db
      .from('lineup_players')
      .select('id, lineup_id, club_id, player_id, position_code, player_profiles(*)')
      .eq('club_id', clubId)
      .eq('lineup_id', lineupId);

    return ((optionalData(response) as LineupPlayerRow[] | null) ?? []);
  }

  async listAssignmentsForLineups(
    lineupIds: Array<string | number>,
    principal: RequestPrincipal,
  ): Promise<LineupPlayerRow[]> {
    const clubId = this.requireClubId(principal);
    if (lineupIds.length === 0) {
      return [];
    }

    const response = await this.db
      .from('lineup_players')
      .select('id, lineup_id, club_id, player_id, position_code, player_profiles(*)')
      .eq('club_id', clubId)
      .in('lineup_id', lineupIds);

    return ((optionalData(response) as LineupPlayerRow[] | null) ?? []);
  }

  async replaceLineupPlayers(
    lineupId: string | number,
    assignments: LineupAssignmentInput[],
    principal: RequestPrincipal,
  ): Promise<void> {
    const clubId = this.requireClubId(principal);
    this.ensureCanManageLineups(principal);
    await this.getLineupOrThrow(lineupId, clubId);
    await this.ensurePlayersBelongToClub(assignments, clubId);

    const deleteResponse = await this.db
      .from('lineup_players')
      .delete()
      .eq('club_id', clubId)
      .eq('lineup_id', lineupId);
    ensureSuccess(deleteResponse);

    if (assignments.length === 0) {
      return;
    }

    const insertResponse = await this.db.from('lineup_players').insert(
      assignments.map((assignment) => ({
        club_id: clubId,
        lineup_id: lineupId,
        player_id: assignment.player_id,
        position_code: assignment.position_code.trim(),
      })),
    );

    ensureSuccess(insertResponse);
  }

  private requireClubId(principal: RequestPrincipal): string | number {
    const clubId = principal.membership?.club_id;
    if (!clubId) {
      throw new ForbiddenError('Devi appartenere a un club per usare le formazioni');
    }

    return clubId;
  }

  private ensureCanManageLineups(principal: RequestPrincipal): void {
    if (!principal.canManageLineups) {
      throw new ForbiddenError('Non hai i permessi per gestire le formazioni');
    }
  }

  private async getLineupOrThrow(
    lineupId: string | number,
    clubId: string | number,
  ): Promise<LineupRow> {
    const response = await this.db
      .from('lineups')
      .select('*')
      .eq('id', lineupId)
      .eq('club_id', clubId)
      .maybeSingle();

    return requiredData(response, 'Formazione non trovata') as LineupRow;
  }

  private async ensurePlayersBelongToClub(
    assignments: LineupAssignmentInput[],
    clubId: string | number,
  ): Promise<void> {
    const playerIds = [...new Set(assignments.map((assignment) => assignment.player_id))];
    if (playerIds.length === 0) {
      return;
    }

    const response = await this.db
      .from('player_profiles')
      .select('id')
      .eq('club_id', clubId)
      .is('archived_at', null)
      .in('id', playerIds);
    const allowedIds = new Set(
      ((optionalData(response) as Array<{ id: string | number }> | null) ?? []).map((row) => `${row.id}`),
    );

    for (const playerId of playerIds) {
      if (!allowedIds.has(`${playerId}`)) {
        throw new NotFoundError('Uno o piu giocatori non appartengono al club corrente');
      }
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
