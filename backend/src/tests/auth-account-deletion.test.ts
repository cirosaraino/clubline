import assert from 'node:assert/strict';
import test from 'node:test';

import type { JoinRequestRow, MembershipRow, PlayerProfileRow } from '../domain/types';
import { ConflictError } from '../lib/errors';
import { AuthService } from '../services/auth.service';
import { FakeSupabaseClient } from './support/fake-supabase';

function createMembership(overrides: Partial<MembershipRow> = {}): MembershipRow {
  return {
    id: 1,
    club_id: 1,
    auth_user_id: 'user-1',
    role: 'player',
    status: 'active',
    left_at: null,
    created_at: '2026-04-21T09:00:00.000Z',
    updated_at: '2026-04-21T09:00:00.000Z',
    ...overrides,
  };
}

function createJoinRequest(overrides: Partial<JoinRequestRow> = {}): JoinRequestRow {
  return {
    id: 1,
    club_id: 1,
    requester_user_id: 'user-1',
    requester_email: 'user-1@example.com',
    requested_nome: 'Mario',
    requested_cognome: 'Rossi',
    requested_shirt_number: null,
    requested_primary_role: null,
    status: 'pending',
    decided_by_membership_id: null,
    decided_at: null,
    cancelled_at: null,
    expires_at: null,
    created_at: '2026-04-21T09:00:00.000Z',
    updated_at: '2026-04-21T09:00:00.000Z',
    ...overrides,
  };
}

function createPlayerProfile(
  overrides: Partial<PlayerProfileRow> = {},
): PlayerProfileRow {
  return {
    id: 1,
    club_id: 1,
    membership_id: null,
    nome: 'Mario',
    cognome: 'Rossi',
    auth_user_id: 'user-1',
    account_email: 'user-1@example.com',
    shirt_number: null,
    primary_role: null,
    secondary_role: null,
    secondary_roles: [],
    id_console: 'mario-rossi',
    team_role: 'player',
    archived_at: null,
    created_at: '2026-04-21T09:00:00.000Z',
    updated_at: '2026-04-21T09:00:00.000Z',
    ...overrides,
  };
}

function createAuthAdminDb(
  seed: Partial<Record<string, Record<string, any>[]>> = {},
): FakeSupabaseClient & { deletedUserIds: string[] } {
  const db = new FakeSupabaseClient(seed) as FakeSupabaseClient & {
    auth: {
      admin: {
        deleteUser: (userId: string) => Promise<{ data: null; error: null }>;
      };
    };
    deletedUserIds: string[];
  };

  db.deletedUserIds = [];
  db.auth = {
    admin: {
      deleteUser: async (userId: string) => {
        db.deletedUserIds.push(userId);
        return { data: null, error: null };
      },
    },
  };

  return db;
}

test('deleteAccount blocks users with an active membership', async () => {
  const adminDb = createAuthAdminDb({
    memberships: [createMembership()],
  });
  const service = new AuthService({} as any, adminDb as any);

  await assert.rejects(
    () => service.deleteAccount('user-1'),
    (error: unknown) =>
      error instanceof ConflictError &&
      error.message.includes('Esci dal club'),
  );
  assert.deepEqual(adminDb.deletedUserIds, []);
});

test('deleteAccount blocks users with a pending join request', async () => {
  const adminDb = createAuthAdminDb({
    join_requests: [createJoinRequest()],
  });
  const service = new AuthService({} as any, adminDb as any);

  await assert.rejects(
    () => service.deleteAccount('user-1'),
    (error: unknown) =>
      error instanceof ConflictError &&
      error.message.includes('richiesta di ingresso'),
  );
  assert.deepEqual(adminDb.deletedUserIds, []);
});

test('deleteAccount archives standalone profiles and deletes the auth user', async () => {
  const adminDb = createAuthAdminDb({
    player_profiles: [
      createPlayerProfile(),
      createPlayerProfile({
        id: 2,
        archived_at: '2026-04-19T08:00:00.000Z',
        nome: 'Storico',
      }),
    ],
  });
  const service = new AuthService({} as any, adminDb as any);

  await service.deleteAccount('user-1');

  const updatedProfile = adminDb.findById<PlayerProfileRow>('player_profiles', 1);
  const archivedProfile = adminDb.findById<PlayerProfileRow>('player_profiles', 2);
  assert.equal(updatedProfile?.auth_user_id, null);
  assert.equal(updatedProfile?.account_email, null);
  assert.ok(updatedProfile?.archived_at);
  assert.equal(archivedProfile?.auth_user_id, null);
  assert.equal(archivedProfile?.account_email, null);
  assert.equal(archivedProfile?.archived_at, '2026-04-19T08:00:00.000Z');
  assert.deepEqual(adminDb.deletedUserIds, ['user-1']);
});
