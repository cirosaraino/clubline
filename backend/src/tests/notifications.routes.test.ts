import assert from 'node:assert/strict';
import test from 'node:test';

import type { AppNotificationRow, RequestPrincipal, VicePermissionsRow } from '../domain/types';
import { createNotificationsRouter } from '../routes/notifications.routes';
import { FakeSupabaseClient } from './support/fake-supabase';
import { authAs, withTestServer } from './support/http-test-helpers';

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
    id: 10,
    recipient_user_id: 'user-1',
    club_id: 1,
    notification_type: 'club_invite_received',
    title: 'Invito ricevuto',
    body: 'Hai ricevuto un invito',
    metadata: { inviteId: 10 },
    related_invite_id: 10,
    read_at: null,
    dedupe_key: 'club_invite_received:10',
    created_at: '2026-05-04T10:00:00.000Z',
    ...overrides,
  };
}

test('GET /notifications returns unreadCount and POST /notifications/read-all marks notifications as read', async () => {
  const published: Array<{ scopes: string[]; reason: string }> = [];
  const db = new FakeSupabaseClient({
    app_notifications: [
      createNotification({ id: 10, read_at: null }),
      createNotification({ id: 11, read_at: null, dedupe_key: 'club_invite_received:11' }),
    ],
  });

  const router = createNotificationsRouter({
    db: db as any,
    authMiddleware: authAs(buildPrincipal('user-1')),
    publishChange: (scopes, reason = 'updated') => {
      published.push({ scopes, reason });
      return null as any;
    },
  });

  await withTestServer(router, async (baseUrl) => {
    const listResponse = await fetch(`${baseUrl}/?filter=all&limit=20`);
    assert.equal(listResponse.status, 200);
    const listPayload = await listResponse.json();
    assert.equal(listPayload.unreadCount, 2);

    const readAllResponse = await fetch(`${baseUrl}/read-all`, {
      method: 'POST',
    });
    assert.equal(readAllResponse.status, 200);
    const readAllPayload = await readAllResponse.json();
    assert.equal(readAllPayload.unreadCount, 0);
  });

  assert.deepEqual(published, [
    {
      scopes: ['notifications'],
      reason: 'notifications_read_all',
    },
  ]);
});

test('POST /notifications/:id/read is idempotent and publishes notifications scope', async () => {
  const published: Array<{ scopes: string[]; reason: string }> = [];
  const db = new FakeSupabaseClient({
    app_notifications: [
      createNotification({ id: 12, read_at: '2026-05-04T10:30:00.000Z' }),
    ],
  });

  const router = createNotificationsRouter({
    db: db as any,
    authMiddleware: authAs(buildPrincipal('user-1')),
    publishChange: (scopes, reason = 'updated') => {
      published.push({ scopes, reason });
      return null as any;
    },
  });

  await withTestServer(router, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/12/read`, {
      method: 'POST',
    });

    assert.equal(response.status, 200);
    const payload = await response.json();
    assert.equal(payload.success, true);
    assert.equal(payload.notification.id, 12);
    assert.equal(payload.unreadCount, 0);
  });

  assert.deepEqual(published, [
    {
      scopes: ['notifications'],
      reason: 'notification_read',
    },
  ]);
});
