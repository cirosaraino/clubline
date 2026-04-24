import type { SupabaseClient } from '@supabase/supabase-js';

import type {
  AttendanceEntryRow,
  AttendanceLineupFiltersDto,
  AttendanceWeekRow,
  RequestPrincipal,
} from '../domain/types';
import { ConflictError, ForbiddenError, NotFoundError } from '../lib/errors';
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

function parseAttendanceTimestamp(value: string | null | undefined): number {
  if (!value) {
    return 0;
  }

  const timestamp = Date.parse(value);
  return Number.isNaN(timestamp) ? 0 : timestamp;
}

function compareAttendanceEntryRecency(
  left: AttendanceEntryRow,
  right: AttendanceEntryRow,
): number {
  const leftResolved = left.availability !== 'pending';
  const rightResolved = right.availability !== 'pending';
  if (leftResolved != rightResolved) {
    return leftResolved ? 1 : -1;
  }

  const updatedCompare =
    parseAttendanceTimestamp(left.updated_at) - parseAttendanceTimestamp(right.updated_at);
  if (updatedCompare != 0) {
    return updatedCompare;
  }

  const createdCompare =
    parseAttendanceTimestamp(left.created_at) - parseAttendanceTimestamp(right.created_at);
  if (createdCompare != 0) {
    return createdCompare;
  }

  const leftId = Number(left.id);
  const rightId = Number(right.id);
  if (Number.isFinite(leftId) && Number.isFinite(rightId) && leftId != rightId) {
    return leftId - rightId;
  }

  return `${left.id}`.localeCompare(`${right.id}`);
}

function deduplicateAttendanceEntries(rows: AttendanceEntryRow[]): AttendanceEntryRow[] {
  const byKey = new Map<string, AttendanceEntryRow>();

  for (const row of rows) {
    const key = `${row.week_id}_${row.player_id}_${normalizeDateOnly(row.attendance_date)}`;
    const current = byKey.get(key);
    if (!current || compareAttendanceEntryRecency(current, row) < 0) {
      byKey.set(key, row);
    }
  }

  return [...byKey.values()];
}

function calculateWeekStart(referenceDate: string): string {
  const date = new Date(`${normalizeDateOnly(referenceDate)}T00:00:00.000Z`);
  const utcDay = date.getUTCDay() || 7;
  date.setUTCDate(date.getUTCDate() - utcDay + 1);
  return date.toISOString().slice(0, 10);
}

function addDays(dateOnly: string, amount: number): string {
  const date = new Date(`${normalizeDateOnly(dateOnly)}T00:00:00.000Z`);
  date.setUTCDate(date.getUTCDate() + amount);
  return date.toISOString().slice(0, 10);
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

  async getActiveWeek(principal: RequestPrincipal): Promise<AttendanceWeekRow | null> {
    const clubId = this.requireClubId(principal);
    const response = await this.db
      .from('attendance_weeks')
      .select('*')
      .eq('club_id', clubId)
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
    const clubId = this.requireClubId(principal);
    this.ensureCanManageAttendance(principal);

    const weekStart = calculateWeekStart(input.reference_date);
    const weekEnd = addDays(weekStart, 6);
    const selectedDates = normalizeDates(input.selected_dates);
    if (selectedDates.length === 0) {
      throw new ConflictError('Seleziona almeno un giorno valido per la settimana scelta');
    }

    for (const selectedDate of selectedDates) {
      if (selectedDate < weekStart || selectedDate > weekEnd) {
        throw new ConflictError('Tutti i giorni selezionati devono appartenere alla stessa settimana');
      }
    }

    const existingActive = await this.getActiveWeek(principal);
    if (existingActive) {
      throw new ConflictError('Archivia prima la settimana presenze attiva');
    }

    const response = await this.db
      .from('attendance_weeks')
      .insert({
        club_id: clubId,
        week_start: weekStart,
        week_end: weekEnd,
        selected_dates: selectedDates,
      })
      .select('*')
      .single();

    const week = requiredData(response) as AttendanceWeekRow;
    await this.syncWeekEntries(week.id, clubId);
    return week;
  }

  async syncWeekEntriesForManager(
    weekId: string | number,
    principal: RequestPrincipal,
  ): Promise<void> {
    this.ensureCanManageAttendance(principal);
    const clubId = this.requireClubId(principal);
    await this.syncWeekEntries(weekId, clubId);
  }

  async syncWeekEntries(weekId: string | number, clubId: string | number): Promise<void> {
    const week = await this.getWeekById(weekId, clubId);
    const playersResponse = await this.db
      .from('player_profiles')
      .select('id')
      .eq('club_id', clubId)
      .is('archived_at', null);
    const playerIds = ((optionalData(playersResponse) as Array<{ id: number | string }> | null) ?? [])
      .map((row) => row.id);

    const existingEntriesResponse = await this.db
      .from('attendance_entries')
      .select('player_id, attendance_date')
      .eq('club_id', clubId)
      .eq('week_id', week.id);
    const existingEntries = ((optionalData(existingEntriesResponse) as Array<{
      player_id: number | string;
      attendance_date: string;
    }> | null) ?? []);
    const existingKeys = new Set(
      existingEntries.map(
        (entry) => `${entry.player_id}_${normalizeDateOnly(entry.attendance_date)}`,
      ),
    );

    const missingEntries: Array<Record<string, unknown>> = [];

    for (const playerId of playerIds) {
      for (const attendanceDate of week.selected_dates) {
        const entryKey = `${playerId}_${normalizeDateOnly(attendanceDate)}`;
        if (existingKeys.has(entryKey)) {
          continue;
        }

        missingEntries.push({
          club_id: clubId,
          week_id: week.id,
          player_id: playerId,
          attendance_date: attendanceDate,
          availability: 'pending',
        });
        existingKeys.add(entryKey);
      }
    }

    if (missingEntries.length === 0) {
      return;
    }

    const response = await this.db.from('attendance_entries').insert(missingEntries);
    ensureSuccess(response);
  }

  async archiveWeek(weekId: string | number, principal: RequestPrincipal): Promise<void> {
    const clubId = this.requireClubId(principal);
    this.ensureCanManageAttendance(principal);
    const response = await this.db
      .from('attendance_weeks')
      .update({ archived_at: new Date().toISOString() })
      .eq('id', weekId)
      .eq('club_id', clubId)
      .is('archived_at', null);
    ensureSuccess(response);
  }

  async restoreArchivedWeek(
    weekId: string | number,
    principal: RequestPrincipal,
  ): Promise<void> {
    const clubId = this.requireClubId(principal);
    this.ensureCanManageAttendance(principal);

    const activeWeek = await this.getActiveWeek(principal);
    if (activeWeek && `${activeWeek.id}` !== `${weekId}`) {
      throw new ConflictError('Esiste gia una settimana presenze attiva');
    }

    const response = await this.db
      .from('attendance_weeks')
      .update({ archived_at: null })
      .eq('id', weekId)
      .eq('club_id', clubId)
      .not('archived_at', 'is', null);
    ensureSuccess(response);
    await this.syncWeekEntries(weekId, clubId);
  }

  async deleteArchivedWeek(
    weekId: string | number,
    principal: RequestPrincipal,
  ): Promise<void> {
    const clubId = this.requireClubId(principal);
    this.ensureCanManageAttendance(principal);

    const week = await this.getWeekById(weekId, clubId);
    if (!week.archived_at) {
      throw new ConflictError('Puoi eliminare solo settimane gia archiviate');
    }

    const response = await this.db
      .from('attendance_weeks')
      .delete()
      .eq('id', weekId)
      .eq('club_id', clubId);
    ensureSuccess(response);
  }

  async listEntriesForWeek(
    weekId: string | number,
    principal: RequestPrincipal,
  ): Promise<AttendanceEntryRow[]> {
    const clubId = this.requireClubId(principal);
    const week = await this.getWeekById(weekId, clubId);
    if (week.archived_at && !principal.canManageAttendance) {
      throw new ForbiddenError('Solo capitano e vice possono consultare settimane archiviate');
    }

    await this.syncWeekEntries(weekId, clubId);

    let query = this.db
      .from('attendance_entries')
      .select(
        'id, club_id, week_id, player_id, attendance_date, availability, updated_by_player_id, updated_at, created_at, player:player_profiles!attendance_entries_player_id_fkey(*)',
      )
      .eq('club_id', clubId)
      .eq('week_id', weekId);

    if (!principal.canManageAttendance) {
      if (!principal.player) {
        return [];
      }
      query = query.eq('player_id', principal.player.id);
    }

    const response = await query;
    const rows = deduplicateAttendanceEntries(
      ((optionalData(response) as AttendanceEntryRow[] | null) ?? []),
    );

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
    const clubId = this.requireClubId(principal);
    if (!principal.player) {
      throw new ForbiddenError('Profilo club non collegato');
    }

    const week = await this.getWeekById(input.week_id, clubId);
    if (week.archived_at) {
      throw new ConflictError('La settimana presenze e gia archiviata');
    }

    const normalizedAttendanceDate = normalizeDateOnly(input.attendance_date);
    if (!week.selected_dates.includes(normalizedAttendanceDate)) {
      throw new ConflictError('Puoi salvare la presenza solo nei giorni previsti per la settimana');
    }

    const canEditTarget =
      principal.canManageAttendance || `${principal.player.id}` === `${input.player_id}`;
    if (!canEditTarget) {
      throw new ForbiddenError('Puoi modificare solo le tue presenze');
    }

    const playerResponse = await this.db
      .from('player_profiles')
      .select('id')
      .eq('id', input.player_id)
      .eq('club_id', clubId)
      .is('archived_at', null)
      .maybeSingle();
    if (!optionalData(playerResponse)) {
      throw new NotFoundError('Il giocatore selezionato non appartiene al club corrente');
    }

    const response = await this.db.from('attendance_entries').upsert(
      {
        club_id: clubId,
        week_id: input.week_id,
        player_id: input.player_id,
        attendance_date: normalizedAttendanceDate,
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
    const clubId = this.requireClubId(principal);
    this.ensureCanManageAttendance(principal);

    let query = this.db
      .from('attendance_weeks')
      .select('*')
      .eq('club_id', clubId)
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
    const clubId = this.requireClubId(principal);
    if (!principal.canManageLineups) {
      throw new ForbiddenError('Non puoi consultare i filtri presenze per le formazioni');
    }

    const response = await this.db
      .from('attendance_entries')
      .select('player_id, availability')
      .eq('club_id', clubId)
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

  private async getWeekById(
    weekId: string | number,
    clubId: string | number,
  ): Promise<AttendanceWeekRow> {
    const response = await this.db
      .from('attendance_weeks')
      .select('*')
      .eq('id', weekId)
      .eq('club_id', clubId)
      .maybeSingle();

    return requiredData(response, 'Settimana presenze non trovata') as AttendanceWeekRow;
  }

  private requireClubId(principal: RequestPrincipal): string | number {
    const clubId =
      principal.membership?.club_id ??
      principal.player?.club_id ??
      principal.club?.id;
    if (clubId == null || `${clubId}`.trim().length === 0) {
      throw new ForbiddenError('Devi appartenere a un club per usare le presenze');
    }

    return clubId;
  }

  private ensureCanManageAttendance(principal: RequestPrincipal): void {
    if (!principal.canManageAttendance) {
      throw new ForbiddenError('Non hai i permessi per gestire le presenze');
    }
  }
}
