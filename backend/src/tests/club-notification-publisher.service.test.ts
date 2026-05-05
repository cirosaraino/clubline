import assert from 'node:assert/strict';
import test from 'node:test';

import type {
  AttendanceWeekRow,
  AppNotificationRow,
  ClubRow,
  LineupRow,
  MembershipRow,
} from '../domain/types';
import { ClubNotificationPublisherService } from '../services/club-notification-publisher.service';
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

function createLineup(overrides: Partial<LineupRow> = {}): LineupRow {
  return {
    id: 100,
    club_id: 1,
    competition_name: 'Serie A',
    match_datetime: '2026-05-10T20:00:00.000Z',
    opponent_name: 'Rivali FC',
    formation_module: '4-3-3',
    notes: null,
    created_at: '2026-05-05T10:00:00.000Z',
    ...overrides,
  };
}

function createWeek(overrides: Partial<AttendanceWeekRow> = {}): AttendanceWeekRow {
  return {
    id: 77,
    club_id: 1,
    week_start: '2026-05-11',
    week_end: '2026-05-17',
    selected_dates: ['2026-05-12', '2026-05-14'],
    archived_at: null,
    created_at: '2026-05-05T10:00:00.000Z',
    ...overrides,
  };
}

test('publishLineupPublished notifies all active club members, not only lineup players', async () => {
  const db = new FakeSupabaseClient({
    clubs: [createClub()],
    memberships: [
      createMembership({ id: 1, auth_user_id: 'captain-1', role: 'captain' }),
      createMembership({ id: 2, auth_user_id: 'vice-1', role: 'vice_captain' }),
      createMembership({ id: 3, auth_user_id: 'player-1', role: 'player' }),
      createMembership({ id: 4, auth_user_id: 'player-2', role: 'player' }),
      createMembership({ id: 5, auth_user_id: 'left-1', role: 'player', status: 'left' }),
      createMembership({ id: 6, auth_user_id: '', role: 'player' }),
      createMembership({ id: 7, club_id: 2, auth_user_id: 'other-club-user', role: 'player' }),
    ],
    lineup_players: [
      {
        id: 1,
        lineup_id: 100,
        club_id: 1,
        player_id: 201,
        position_code: 'ATT',
      },
    ],
    app_notifications: [],
  });
  const service = new ClubNotificationPublisherService(db as any);

  await service.publishLineupPublished({
    clubId: 1,
    clubName: 'Club Uno',
    lineup: createLineup(),
  });

  const notifications = db.rows<AppNotificationRow>('app_notifications');
  assert.equal(notifications.length, 4);
  assert.deepEqual(
    notifications.map((notification) => notification.recipient_user_id).sort(),
    ['captain-1', 'player-1', 'player-2', 'vice-1'],
  );
  assert.ok(
    notifications.every(
      (notification) => notification.notification_type === 'lineup_published',
    ),
  );
  assert.ok(
    notifications.every(
      (notification) => notification.dedupe_key === 'lineup_published:100',
    ),
  );
});

test('publishLineupPublished dedupes repeated publications for the same lineup', async () => {
  const db = new FakeSupabaseClient({
    clubs: [createClub()],
    memberships: [
      createMembership({ id: 1, auth_user_id: 'captain-1', role: 'captain' }),
      createMembership({ id: 2, auth_user_id: 'vice-1', role: 'vice_captain' }),
    ],
    app_notifications: [],
  });
  const service = new ClubNotificationPublisherService(db as any);

  await service.publishLineupPublished({
    clubId: 1,
    clubName: 'Club Uno',
    lineup: createLineup(),
  });
  await service.publishLineupPublished({
    clubId: 1,
    clubName: 'Club Uno',
    lineup: createLineup({ formation_module: '3-5-2' }),
  });

  const notifications = db.rows<AppNotificationRow>('app_notifications');
  assert.equal(notifications.length, 2);
  assert.ok(
    notifications.every(
      (notification) => notification.metadata['formationModule'] === '3-5-2',
    ),
  );
});

test('publishAttendancePublished notifies all active club members, not only attendance entries', async () => {
  const db = new FakeSupabaseClient({
    clubs: [createClub()],
    memberships: [
      createMembership({ id: 1, auth_user_id: 'captain-1', role: 'captain' }),
      createMembership({ id: 2, auth_user_id: 'vice-1', role: 'vice_captain' }),
      createMembership({ id: 3, auth_user_id: 'player-1', role: 'player' }),
      createMembership({ id: 4, auth_user_id: 'player-2', role: 'player' }),
      createMembership({ id: 5, auth_user_id: 'left-1', role: 'player', status: 'left' }),
      createMembership({ id: 6, auth_user_id: '   ', role: 'player' }),
    ],
    attendance_entries: [
      {
        id: 301,
        club_id: 1,
        week_id: 77,
        player_id: 900,
        attendance_date: '2026-05-12',
        availability: 'pending',
        updated_by_player_id: null,
      },
    ],
    app_notifications: [],
  });
  const service = new ClubNotificationPublisherService(db as any);

  await service.publishAttendancePublished({
    clubId: 1,
    clubName: 'Club Uno',
    week: createWeek(),
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
  assert.ok(
    notifications.every(
      (notification) => notification.dedupe_key === 'attendance_published:77',
    ),
  );
});

test('publishAttendancePublished dedupes repeated publications for the same week', async () => {
  const db = new FakeSupabaseClient({
    clubs: [createClub()],
    memberships: [
      createMembership({ id: 1, auth_user_id: 'captain-1', role: 'captain' }),
      createMembership({ id: 2, auth_user_id: 'vice-1', role: 'vice_captain' }),
    ],
    app_notifications: [],
  });
  const service = new ClubNotificationPublisherService(db as any);

  await service.publishAttendancePublished({
    clubId: 1,
    clubName: 'Club Uno',
    week: createWeek(),
  });
  await service.publishAttendancePublished({
    clubId: 1,
    clubName: 'Club Uno',
    week: createWeek({ selected_dates: ['2026-05-13'] }),
  });

  const notifications = db.rows<AppNotificationRow>('app_notifications');
  assert.equal(notifications.length, 2);
  assert.ok(
    notifications.every(
      (notification) =>
        Array.isArray(notification.metadata['selectedDates']) &&
        (notification.metadata['selectedDates'] as string[]).length === 1,
    ),
  );
});
