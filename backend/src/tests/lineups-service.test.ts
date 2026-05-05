import assert from 'node:assert/strict';
import test from 'node:test';

import type {
  ClubRow,
  LineupPlayerRow,
  LineupRow,
  MembershipRow,
  PlayerProfileRow,
  RequestPrincipal,
  VicePermissionsRow,
} from '../domain/types';
import { LineupsService } from '../services/lineups.service';
import { FakeSupabaseClient } from './support/fake-supabase';

function createClub(overrides: Partial<ClubRow> = {}): ClubRow {
  return {
    id: 1,
    name: 'Club Uno',
    normalized_name: 'club uno',
    slug: 'club-uno',
    logo_url: null,
    logo_storage_path: null,
    primary_color: '#1F2937',
    accent_color: '#0F766E',
    surface_color: '#0F172A',
    created_by_user_id: 'captain-1',
    created_at: '2026-04-20T10:00:00.000Z',
    updated_at: '2026-04-20T10:00:00.000Z',
    ...overrides,
  };
}

function createMembership(overrides: Partial<MembershipRow> = {}): MembershipRow {
  return {
    id: 10,
    club_id: 1,
    auth_user_id: 'captain-1',
    role: 'captain',
    status: 'active',
    left_at: null,
    created_at: '2026-04-20T10:00:00.000Z',
    updated_at: '2026-04-20T10:00:00.000Z',
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
    vice_manage_invites: false,
    vice_manage_team_info: false,
    updated_at: '2026-04-20T10:00:00.000Z',
    ...overrides,
  };
}

function buildPrincipal(options: {
  userId: string;
  club: ClubRow;
  membership: MembershipRow;
  canManageLineups?: boolean;
}): RequestPrincipal {
  return {
    authUser: {
      id: options.userId,
      email: `${options.userId}@example.com`,
      emailVerified: true,
      emailVerifiedAt: '2026-04-20T09:00:00.000Z',
    },
    club: options.club,
    membership: options.membership,
    player: null,
    permissions: createPermissions(options.club.id),
    isCaptain: options.membership.role == 'captain',
    isViceCaptain: options.membership.role == 'vice_captain',
    hasClub: true,
    canManagePlayers: false,
    canManageLineups: options.canManageLineups ?? true,
    canManageStreams: false,
    canManageAttendance: false,
    canManageInvites: false,
    canManageClubInfo: false,
  };
}

function createLineup(overrides: Partial<LineupRow> = {}): LineupRow {
  return {
    id: 100,
    club_id: 1,
    competition_name: 'Serie A',
    match_datetime: '2026-04-20T20:00:00.000Z',
    opponent_name: 'Rivali FC',
    formation_module: '4-3-3 IN LINEA',
    notes: null,
    created_at: '2026-04-20T10:00:00.000Z',
    ...overrides,
  };
}

function createPlayer(overrides: Partial<PlayerProfileRow> = {}): PlayerProfileRow {
  return {
    id: 200,
    club_id: 1,
    membership_id: null,
    nome: 'Mario',
    cognome: 'Rossi',
    auth_user_id: null,
    account_email: null,
    shirt_number: 9,
    primary_role: 'ATT',
    secondary_role: null,
    secondary_roles: [],
    id_console: null,
    team_role: 'player',
    archived_at: null,
    created_at: '2026-04-20T10:00:00.000Z',
    updated_at: '2026-04-20T10:00:00.000Z',
    ...overrides,
  };
}

test('replaceLineupPlayers stores club_id on lineup assignments', async () => {
  const club = createClub();
  const membership = createMembership();
  const db = new FakeSupabaseClient({
    clubs: [club],
    lineups: [createLineup()],
    player_profiles: [createPlayer()],
    lineup_players: [
      {
        id: 1,
        lineup_id: 100,
        club_id: 1,
        player_id: 200,
        position_code: 'ATT',
        created_at: '2026-04-20T10:00:00.000Z',
      },
    ],
  });
  const service = new LineupsService(db as any);

  await service.replaceLineupPlayers(
    100,
    [{ player_id: 200, position_code: 'COC' }],
    buildPrincipal({ userId: 'captain-1', club: club, membership }),
  );

  const assignments = db.rows<LineupPlayerRow>('lineup_players');
  assert.equal(assignments.length, 1);
  assert.equal(assignments[0]?.club_id, 1);
  assert.equal(assignments[0]?.position_code, 'COC');
});

test('listAssignmentsForLineups stays club-scoped through lineup_players.club_id', async () => {
  const club = createClub({ id: 1 });
  const membership = createMembership({ club_id: 1 });
  const db = new FakeSupabaseClient({
    clubs: [club, createClub({ id: 2, name: 'Club Due', normalized_name: 'club due', slug: 'club-due' })],
    lineups: [createLineup({ id: 100, club_id: 1 }), createLineup({ id: 101, club_id: 2 })],
    player_profiles: [createPlayer({ id: 200, club_id: 1 }), createPlayer({ id: 201, club_id: 2 })],
    lineup_players: [
      {
        id: 1,
        lineup_id: 100,
        club_id: 1,
        player_id: 200,
        position_code: 'ATT',
        created_at: '2026-04-20T10:00:00.000Z',
      },
      {
        id: 2,
        lineup_id: 101,
        club_id: 2,
        player_id: 201,
        position_code: 'ATT',
        created_at: '2026-04-20T10:00:00.000Z',
      },
    ],
  });
  const service = new LineupsService(db as any);

  const assignments = await service.listAssignmentsForLineups(
    [100, 101],
    buildPrincipal({ userId: 'captain-1', club, membership }),
  );

  assert.equal(assignments.length, 1);
  assert.equal(assignments[0]?.lineup_id, 100);
  assert.equal(assignments[0]?.club_id, 1);
});
