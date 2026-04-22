import assert from 'node:assert/strict';
import test from 'node:test';

import type {
  AttendanceEntryRow,
  AttendanceWeekRow,
  PlayerProfileRow,
  RequestPrincipal,
  VicePermissionsRow,
} from '../domain/types';
import { AttendanceService } from '../services/attendance.service';
import { FakeSupabaseClient } from './support/fake-supabase';

function createPlayerProfile(
  overrides: Partial<PlayerProfileRow> = {},
): PlayerProfileRow {
  return {
    id: 1,
    club_id: 1,
    membership_id: null,
    nome: 'Mario',
    cognome: 'Rossi',
    auth_user_id: 'player-1',
    account_email: 'player-1@example.com',
    shirt_number: 10,
    primary_role: 'ATT',
    secondary_role: null,
    secondary_roles: [],
    id_console: 'mario-rossi',
    team_role: 'player',
    archived_at: null,
    created_at: '2026-04-22T10:00:00.000Z',
    updated_at: '2026-04-22T10:00:00.000Z',
    ...overrides,
  };
}

function createWeek(
  overrides: Partial<AttendanceWeekRow> = {},
): AttendanceWeekRow {
  return {
    id: 1,
    club_id: 1,
    week_start: '2026-04-20',
    week_end: '2026-04-26',
    selected_dates: ['2026-04-22', '2026-04-24'],
    archived_at: null,
    created_at: '2026-04-22T10:00:00.000Z',
    ...overrides,
  };
}

function createPermissions(
  clubId: number | string,
  overrides: Partial<VicePermissionsRow> = {},
): VicePermissionsRow {
  return {
    club_id: clubId,
    vice_manage_players: false,
    vice_manage_lineups: false,
    vice_manage_streams: false,
    vice_manage_attendance: false,
    vice_manage_team_info: false,
    updated_at: '2026-04-22T10:00:00.000Z',
    ...overrides,
  };
}

function buildPrincipal(options: {
  userId: string;
  player?: PlayerProfileRow | null;
}): RequestPrincipal {
  const player = options.player ?? null;

  return {
    authUser: {
      id: options.userId,
      email: `${options.userId}@example.com`,
      emailVerified: true,
      emailVerifiedAt: '2026-04-22T09:00:00.000Z',
    },
    club: null,
    membership: null,
    player,
    permissions: createPermissions(player?.club_id ?? 0),
    isCaptain: false,
    isViceCaptain: false,
    hasClub: false,
    canManagePlayers: false,
    canManageLineups: false,
    canManageStreams: false,
    canManageAttendance: false,
    canManageTeamInfo: false,
  };
}

test('getActiveWeek resolves club from the linked player profile', async () => {
  const week = createWeek();
  const player = createPlayerProfile();
  const db = new FakeSupabaseClient({
    attendance_weeks: [week],
    player_profiles: [player],
  });
  const service = new AttendanceService(db as any);

  const activeWeek = await service.getActiveWeek(
    buildPrincipal({
      userId: 'player-1',
      player,
    }),
  );

  assert.equal(activeWeek?.id, week.id);
});

test('saveAvailability works when the club is resolved from the linked player profile', async () => {
  const week = createWeek();
  const player = createPlayerProfile();
  const db = new FakeSupabaseClient({
    attendance_weeks: [week],
    player_profiles: [player],
    attendance_entries: [],
  });
  const service = new AttendanceService(db as any);

  await service.saveAvailability(
    {
      week_id: week.id,
      player_id: player.id,
      attendance_date: '2026-04-22',
      availability: 'yes',
    },
    buildPrincipal({
      userId: 'player-1',
      player,
    }),
  );

  const entries = db.rows<AttendanceEntryRow>('attendance_entries');
  assert.equal(entries.length, 1);
  assert.equal(entries[0]?.club_id, week.club_id);
  assert.equal(entries[0]?.player_id, player.id);
  assert.equal(entries[0]?.availability, 'yes');
  assert.equal(entries[0]?.updated_by_player_id, player.id);
});
