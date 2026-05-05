import assert from 'node:assert/strict';
import test from 'node:test';

import type { AppNotificationRow, RequestPrincipal, VicePermissionsRow } from '../domain/types';
import { NotificationsService } from '../services/notifications.service';
import { FakeSupabaseClient } from './support/fake-supabase';

function createPermissions(overrides: Partial<VicePermissionsRow> = {}): VicePermissionsRow {
  return {
    club_id: 0,
    vice_manage_players: false,
    vice_manage_lineups: false,
    vice_manage_streams: false,
    vice_manage_attendance: false,
    vice_manage_invites: false,
    vice_manage_team_info: false,
    updated_at: '2026-05-04T10:00:00.000Z',
    ...overrides,
  };
}

function buildPrincipal(userId: string): RequestPrincipal {
  return {
    authUser: {
      id: userId,
      email: `${userId}@example.com`,
      emailVerified: true,
      emailVerifiedAt: '2026-05-04T09:00:00.000Z',
    },
    club: null,
    membership: null,
    player: null,
    permissions: createPermissions(),
    isCaptain: false,
    isViceCaptain: false,
    hasClub: false,
    canManagePlayers: false,
    canManageLineups: false,
    canManageStreams: false,
    canManageAttendance: false,
    canManageInvites: false,
    canManageClubInfo: false,
  };
}

function createNotification(overrides: Partial<AppNotificationRow> = {}): AppNotificationRow {
  return {
    id: 1,
    recipient_user_id: 'user-1',
    club_id: 1,
    notification_type: 'club_invite_received',
    title: 'Invito ricevuto',
    body: 'Hai ricevuto un invito',
    metadata: { inviteId: 11 },
    related_invite_id: 11,
    read_at: null,
    dedupe_key: 'club_invite_received:11',
    created_at: '2026-05-04T10:00:00.000Z',
    ...overrides,
  };
}

test('listNotifications returns unreadCount and supports unread filter', async () => {
  const db = new FakeSupabaseClient({
    app_notifications: [
      createNotification({ id: 1, read_at: null }),
      createNotification({ id: 2, read_at: '2026-05-04T10:30:00.000Z' }),
      createNotification({ id: 3, read_at: null }),
    ],
  });
  const service = new NotificationsService(db as any);

  const result = await service.listNotifications(
    {
      filter: 'unread',
      limit: 20,
    },
    buildPrincipal('user-1'),
  );

  assert.equal(result.unreadCount, 2);
  assert.deepEqual(
    result.notifications.map((notification) => notification.id),
    [3, 1],
  );
});

test('markRead is idempotent and preserves existing read notifications', async () => {
  const alreadyReadAt = '2026-05-04T10:30:00.000Z';
  const db = new FakeSupabaseClient({
    app_notifications: [
      createNotification({
        id: 2,
        read_at: alreadyReadAt,
      }),
    ],
  });
  const service = new NotificationsService(db as any);

  const result = await service.markRead(2, buildPrincipal('user-1'));

  assert.equal(result.notification.read_at, alreadyReadAt);
  assert.equal(result.unreadCount, 0);
});

test('markAllRead updates unread notifications and returns zero unreadCount', async () => {
  const db = new FakeSupabaseClient({
    app_notifications: [
      createNotification({ id: 1, read_at: null }),
      createNotification({ id: 2, read_at: null }),
      createNotification({
        id: 3,
        recipient_user_id: 'user-2',
        read_at: null,
      }),
    ],
  });
  const service = new NotificationsService(db as any);

  const result = await service.markAllRead(buildPrincipal('user-1'));

  assert.equal(result.unreadCount, 0);
  const rows = db.rows<AppNotificationRow>('app_notifications');
  const userRows = rows.filter((row) => row.recipient_user_id === 'user-1');
  assert.ok(userRows.every((row) => row.read_at != null));
});
