import type { SupabaseClient } from '@supabase/supabase-js';

import type {
  AttendanceEntryRow,
  AttendanceLineupFiltersDto,
  AttendanceWeekRow,
  RequestPrincipal,
} from '../domain/types';
import { ConflictError, ForbiddenError } from '../lib/errors';
import { ensureSuccess, optionalData, requiredData } from '../lib/supabase-result';

function normalizeDateOnly(value: string | Date): string {
  if (value instanceof Date) {
    return value.toISOString().slice(0, 10);
  }

  return value.trim().slice(0, 10);
}

function normalizeDates(values: string[]): string[] {
  return [...new Set(values.map((value) => normalizeDateOnly(value)))].sort();
}

function normalizePlayerName(value: string | null | undefined): string {
  return (value ?? '').trim().toLowerCase();
}

function teamRoleSortIndex(value: string | null | undefined): number {
  switch (value) {
    case 'captain':
      return 0;
    case 'vice_captain':
      return 1;
    case 'player':
    default:
      return 2;
  }
}

export interface CreateAttendanceWeekInput {
  reference_date: string;
  selected_dates: string[];
}

export interface SaveAttendanceAvailabilityInput {
  week_id: number | string;
  player_id: number | string;
  attendance_date: string;
  availability: 'pending' | 'yes' | 'no';
}

export class AttendanceService {
  constructor(private readonly db: SupabaseClient) {}

  async getActiveWeek(): Promise<AttendanceWeekRow | null> {
    const response = await this.db
      .from('attendance_weeks')
      .select('*')
      .is('archived_at', null)
      .order('week_start', { ascending: false })
      .limit(1)
      .maybeSingle();

    return optionalData(response) as AttendanceWeekRow | null;
  }

  async createWeek(
    input: CreateAttendanceWeekInput,
    principal: RequestPrincipal,
  ): Promise<AttendanceWeekRow | null> {
    this.ensureCanManageAttendance(principal);

    const response = await this.db.rpc('create_attendance_week', {
      reference_date: normalizeDateOnly(input.reference_date),
      selected_dates: normalizeDates(input.selected_dates),
    });

    const weekId = optionalData(response) as number | string | null;
    if (weekId == null) {
      return null;
    }

    return this.getWeekById(weekId);
  }

  async syncWeekEntries(weekId: string | number): Promise<void> {
    const response = await this.db.rpc('sync_attendance_entries_for_week', {
      target_week_id: weekId,
    });
    ensureSuccess(response);
  }

  async archiveWeek(weekId: string | number, principal: RequestPrincipal): Promise<void> {
    this.ensureCanManageAttendance(principal);
    const response = await this.db.rpc('archive_attendance_week', {
      target_week_id: weekId,
    });
    ensureSuccess(response);
  }

  async restoreArchivedWeek(
    weekId: string | number,
    principal: RequestPrincipal,
  ): Promise<void> {
    this.ensureCanManageAttendance(principal);
    const response = await this.db.rpc('restore_attendance_week', {
      target_week_id: weekId,
    });
    ensureSuccess(response);
  }

  async deleteArchivedWeek(
    weekId: string | number,
    principal: RequestPrincipal,
  ): Promise<void> {
    this.ensureCanManageAttendance(principal);

    const week = await this.getWeekById(weekId);
    if (!week.archived_at) {
      throw new ConflictError('Puoi eliminare solo settimane gia archiviate');
    }

    const response = await this.db.from('attendance_weeks').delete().eq('id', weekId);
    ensureSuccess(response);
  }

  async listEntriesForWeek(
    weekId: string | number,
    principal: RequestPrincipal,
  ): Promise<AttendanceEntryRow[]> {
    await this.syncWeekEntries(weekId);

    let query = this.db
      .from('attendance_entries')
      .select(
        'id, week_id, player_id, attendance_date, availability, updated_by_player_id, updated_at, created_at, player:player_profiles!attendance_entries_player_id_fkey(*)',
      )
      .eq('week_id', weekId);

    if (!principal.canManageAttendance) {
      if (!principal.player) {
        return [];
      }
      query = query.eq('player_id', principal.player.id);
    }

    const response = await query;
    const rows = ((optionalData(response) as AttendanceEntryRow[] | null) ?? []);

    return [...rows].sort((left, right) => {
      const leftPlayer = left.player;
      const rightPlayer = right.player;
      if (!leftPlayer || !rightPlayer) {
        return new Date(left.attendance_date).getTime() - new Date(right.attendance_date).getTime();
      }

      const managerCompare = teamRoleSortIndex(leftPlayer.team_role) - teamRoleSortIndex(rightPlayer.team_role);
      if (managerCompare != 0) {
        return managerCompare;
      }

      const surnameCompare = normalizePlayerName(leftPlayer.cognome).localeCompare(
        normalizePlayerName(rightPlayer.cognome),
      );
      if (surnameCompare != 0) {
        return surnameCompare;
      }

      const nameCompare = normalizePlayerName(leftPlayer.nome).localeCompare(
        normalizePlayerName(rightPlayer.nome),
      );
      if (nameCompare != 0) {
        return nameCompare;
      }

      return new Date(left.attendance_date).getTime() - new Date(right.attendance_date).getTime();
    });
  }

  async saveAvailability(
    input: SaveAttendanceAvailabilityInput,
    principal: RequestPrincipal,
  ): Promise<void> {
    if (!principal.player) {
      throw new ForbiddenError('Profilo squadra non collegato');
    }

    const canEditTarget =
      principal.canManageAttendance || `${principal.player.id}` === `${input.player_id}`;
    if (!canEditTarget) {
      throw new ForbiddenError('Puoi modificare solo le tue presenze');
    }

    const response = await this.db.from('attendance_entries').upsert(
      {
        week_id: input.week_id,
        player_id: input.player_id,
        attendance_date: normalizeDateOnly(input.attendance_date),
        availability: input.availability,
        updated_by_player_id: principal.player.id,
        updated_at: new Date().toISOString(),
      },
      {
        onConflict: 'week_id,player_id,attendance_date',
      },
    );

    ensureSuccess(response);
  }

  async listArchivedWeeks(
    principal: RequestPrincipal,
    options: {
      excludingWeekId?: string | number;
      limit?: number;
    } = {},
  ): Promise<AttendanceWeekRow[]> {
    this.ensureCanManageAttendance(principal);

    let query = this.db
      .from('attendance_weeks')
      .select('*')
      .not('archived_at', 'is', null)
      .order('week_start', { ascending: false });

    if (options.excludingWeekId != null) {
      query = query.neq('id', options.excludingWeekId);
    }

    if (options.limit != null) {
      query = query.limit(options.limit);
    }

    const response = await query;
    return ((optionalData(response) as AttendanceWeekRow[] | null) ?? []);
  }

  async getLineupFiltersForDate(
    targetDate: string,
    principal: RequestPrincipal,
  ): Promise<AttendanceLineupFiltersDto> {
    if (!principal.canManageLineups) {
      throw new ForbiddenError('Non puoi consultare i filtri presenze per le formazioni');
    }

    const response = await this.db
      .from('attendance_entries')
      .select('player_id, availability')
      .eq('attendance_date', normalizeDateOnly(targetDate));

    const rows = (optionalData(response) as Array<{
      player_id: string | number | null;
      availability: 'pending' | 'yes' | 'no' | null;
    }> | null) ?? [];

    const absentPlayerIds = new Set<string | number>();
    const pendingPlayerIds = new Set<string | number>();

    for (const row of rows) {
      if (row.player_id == null) {
        continue;
      }

      if (row.availability === 'no') {
        absentPlayerIds.add(row.player_id);
      } else if (row.availability === 'pending') {
        pendingPlayerIds.add(row.player_id);
      }
    }

    return {
      absentPlayerIds: [...absentPlayerIds],
      pendingPlayerIds: [...pendingPlayerIds],
    };
  }

  private async getWeekById(weekId: string | number): Promise<AttendanceWeekRow> {
    const response = await this.db
      .from('attendance_weeks')
      .select('*')
      .eq('id', weekId)
      .maybeSingle();

    return requiredData(response, 'Settimana presenze non trovata') as AttendanceWeekRow;
  }

  private ensureCanManageAttendance(principal: RequestPrincipal): void {
    if (!principal.canManageAttendance) {
      throw new ForbiddenError('Non hai i permessi per gestire le presenze');
    }
  }
}
