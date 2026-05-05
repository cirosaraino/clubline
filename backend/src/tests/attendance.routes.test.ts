import assert from 'node:assert/strict';
import test from 'node:test';

import type {
  AppNotificationRow,
  ClubRow,
  MembershipRow,
  PlayerProfileRow,
  RequestPrincipal,
  VicePermissionsRow,
} from '../domain/types';
import { createAttendanceRouter } from '../routes/attendance.routes';
import { FakeSupabaseClient } from './support/fake-supabase';
import { authAs, withTestServer } from './support/http-test-helpers';

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
    created_at: '2026-05-05T10:00:00.000Z',
    updated_at: '2026-05-05T10:00:00.000Z',
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
    created_at: '2026-05-05T10:00:00.000Z',
    updated_at: '2026-05-05T10:00:00.000Z',
    ...overrides,
  };
}

function createPermissions(overrides: Partial<VicePermissionsRow> = {}): VicePermissionsRow {
  return {
    club_id: 1,
    vice_manage_players: false,
    vice_manage_lineups: false,
    vice_manage_streams: false,
    vice_manage_attendance: false,
    vice_manage_invites: false,
    vice_manage_team_info: false,
    updated_at: '2026-05-05T10:00:00.000Z',
    ...overrides,
  };
}

function createPlayer(overrides: Partial<PlayerProfileRow> = {}): PlayerProfileRow {
  return {
    id: 201,
    club_id: 1,
    membership_id: null,
    nome: 'Mario',
    cognome: 'Rossi',
    auth_user_id: 'player-1',
    account_email: 'player-1@example.com',
    shirt_number: 9,
    primary_role: 'ATT',
    secondary_role: null,
    secondary_roles: [],
    id_console: 'mario-rossi',
    team_role: 'player',
    archived_at: null,
    created_at: '2026-05-05T10:00:00.000Z',
    updated_at: '2026-05-05T10:00:00.000Z',
    ...overrides,
  };
}

function buildPrincipal(): RequestPrincipal {
  const club = createClub();
  const membership = createMembership();

  return {
    authUser: {
      id: 'captain-1',
      email: 'captain@example.com',
      emailVerified: true,
      emailVerifiedAt: '2026-05-05T09:00:00.000Z',
    },
    club,
    membership,
    player: null,
    permissions: createPermissions(),
    isCaptain: true,
    isViceCaptain: false,
    hasClub: true,
    canManagePlayers: false,
    canManageLineups: false,
    canManageStreams: false,
    canManageAttendance: true,
    canManageInvites: false,
    canManageClubInfo: false,
  };
}

test('POST /attendance/weeks creates club-wide attendance notifications and publishes notifications scope', async () => {
  const published: Array<{ scopes: string[]; reason: string }> = [];
  const db = new FakeSupabaseClient({
    clubs: [createClub()],
    player_profiles: [createPlayer()],
    memberships: [
      createMembership({ id: 1, auth_user_id: 'captain-1', role: 'captain' }),
      createMembership({ id: 2, auth_user_id: 'vice-1', role: 'vice_captain' }),
      createMembership({ id: 3, auth_user_id: 'player-1', role: 'player' }),
      createMembership({ id: 4, auth_user_id: 'player-2', role: 'player' }),
      createMembership({ id: 5, auth_user_id: 'left-1', role: 'player', status: 'left' }),
    ],
    attendance_weeks: [],
    attendance_entries: [],
    app_notifications: [],
  });

  const router = createAttendanceRouter({
    db: db as any,
    authMiddleware: authAs(buildPrincipal()),
    publishChange: (scopes, reason = 'updated') => {
      published.push({ scopes, reason });
      return null as any;
    },
  });

  await withTestServer(router, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/weeks`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        reference_date: '2026-05-12',
        selected_dates: ['2026-05-12', '2026-05-14'],
      }),
    });

    assert.equal(response.status, 201);
  });

  const notifications = db.rows<AppNotificationRow>('app_notifications');
  assert.equal(notifications.length, 4);
  assert.deepEqual(
    notifications.map((notification) => notification.recipient_user_id).sort(),
    ['captain-1', 'player-1', 'player-2', 'vice-1'],
  );
  assert.ok(
    notifications.every(
      (notification) => notification.notification_type === 'attendance_published',
    ),
  );
  assert.deepEqual(published, [
    {
      scopes: ['attendance', 'lineups', 'notifications'],
      reason: 'attendance_week_created',
    },
  ]);
});
