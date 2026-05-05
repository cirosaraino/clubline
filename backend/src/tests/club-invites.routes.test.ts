import assert from 'node:assert/strict';
import test from 'node:test';

import type {
  ClubInviteRow,
  ClubRow,
  MembershipRow,
  RequestPrincipal,
  VicePermissionsRow,
} from '../domain/types';
import { createClubInvitesRouter } from '../routes/club-invites.routes';
import { FakeSupabaseClient } from './support/fake-supabase';
import { authAs, withTestServer } from './support/http-test-helpers';

function createClub(): ClubRow {
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
    created_at: '2026-05-04T10:00:00.000Z',
    updated_at: '2026-05-04T10:00:00.000Z',
  };
}

function createMembership(): MembershipRow {
  return {
    id: 10,
    club_id: 1,
    auth_user_id: 'captain-1',
    role: 'captain',
    status: 'active',
    left_at: null,
    created_at: '2026-05-04T10:00:00.000Z',
    updated_at: '2026-05-04T10:00:00.000Z',
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
    updated_at: '2026-05-04T10:00:00.000Z',
    ...overrides,
  };
}

function buildPrincipal(canManageInvites = true): RequestPrincipal {
  const membership = createMembership();
  return {
    authUser: {
      id: membership.auth_user_id,
      email: 'captain@example.com',
      emailVerified: true,
      emailVerifiedAt: '2026-05-04T09:00:00.000Z',
    },
    club: createClub(),
    membership,
    player: null,
    permissions: createPermissions(),
    isCaptain: true,
    isViceCaptain: false,
    hasClub: true,
    canManagePlayers: false,
    canManageLineups: false,
    canManageStreams: false,
    canManageAttendance: false,
    canManageInvites,
    canManageClubInfo: false,
  };
}

function createInvite(overrides: Partial<ClubInviteRow> = {}): ClubInviteRow {
  return {
    id: 55,
    club_id: 1,
    created_by_user_id: 'captain-1',
    created_by_membership_id: 10,
    target_user_id: '00000000-0000-0000-0000-000000000001',
    target_player_profile_id: 201,
    target_account_email: 'target@example.com',
    target_nome: 'Mario',
    target_cognome: 'Rossi',
    target_id_console: 'mario-console',
    target_primary_role: 'ATT',
    status: 'pending',
    resolved_at: null,
    resolved_by_user_id: null,
    resolved_by_membership_id: null,
    accepted_membership_id: null,
    accepted_player_id: null,
    created_at: '2026-05-04T10:00:00.000Z',
    updated_at: '2026-05-04T10:00:00.000Z',
    ...overrides,
  };
}

test('POST /club-invites creates an invite and publishes realtime scopes', async () => {
  const published: Array<{ scopes: string[]; reason: string }> = [];
  const db = Object.assign(
    new FakeSupabaseClient({
      club_invites: [createInvite()],
    }),
    {
      rpc: async () => ({
        data: {
          invite_id: 55,
          club_id: 1,
          target_user_id: '00000000-0000-0000-0000-000000000001',
          notification_id: 88,
        },
        error: null,
      }),
    },
  );

  const router = createClubInvitesRouter({
    db: db as any,
    authMiddleware: authAs(buildPrincipal(true)),
    publishChange: (scopes, reason = 'updated') => {
      published.push({ scopes, reason });
      return null as any;
    },
  });

  await withTestServer(router, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        targetUserId: '00000000-0000-0000-0000-000000000001',
      }),
    });

    assert.equal(response.status, 201);
    const payload = await response.json();
    assert.equal(payload.invite.id, 55);
  });

  assert.deepEqual(published, [
    {
      scopes: ['invites', 'notifications'],
      reason: 'club_invite_created',
    },
  ]);
});

test('POST /club-invites returns 403 when principal cannot manage invites', async () => {
  const router = createClubInvitesRouter({
    db: new FakeSupabaseClient() as any,
    authMiddleware: authAs(buildPrincipal(false)),
  });

  await withTestServer(router, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        targetUserId: '00000000-0000-0000-0000-000000000001',
      }),
    });

    assert.equal(response.status, 403);
    const payload = await response.json();
    assert.equal(payload.error.code, 'forbidden');
  });
});

test('POST /club-invites maps duplicate invite conflicts to 409', async () => {
  const db = Object.assign(new FakeSupabaseClient(), {
    rpc: async () => ({
      data: null,
      error: {
        code: 'P0001',
        message: 'Esiste gia un invito pendente per questo utente in questo club',
        details: 'pending_club_invite_exists',
      },
    }),
  });

  const router = createClubInvitesRouter({
    db: db as any,
    authMiddleware: authAs(buildPrincipal(true)),
  });

  await withTestServer(router, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        targetUserId: '00000000-0000-0000-0000-000000000001',
      }),
    });

    assert.equal(response.status, 409);
    const payload = await response.json();
    assert.equal(payload.error.code, 'pending_club_invite_exists');
  });
});

test('GET /club-invites/received returns nested club info without internal club fields', async () => {
  const invite = createInvite({
    id: 66,
    target_user_id: 'target-1',
    target_account_email: 'target@example.com',
    target_nome: 'Mario',
    target_cognome: 'Rossi',
    target_id_console: 'mario-console',
    club: {
      ...createClub(),
      logo_storage_path: 'clubs/1/logo.png',
      created_by_user_id: 'captain-1',
      created_at: '2026-05-04T10:00:00.000Z',
      updated_at: '2026-05-04T10:00:00.000Z',
    },
  });
  const principal: RequestPrincipal = {
    ...buildPrincipal(false),
    authUser: {
      id: 'target-1',
      email: 'target@example.com',
      emailVerified: true,
      emailVerifiedAt: '2026-05-04T09:00:00.000Z',
    },
    club: null,
    membership: null,
    hasClub: false,
    isCaptain: false,
    canManageInvites: false,
  };

  const router = createClubInvitesRouter({
    db: new FakeSupabaseClient({
      club_invites: [invite],
    }) as any,
    authMiddleware: authAs(principal),
  });

  await withTestServer(router, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/received`);

    assert.equal(response.status, 200);
    const payload = await response.json();
    assert.equal(payload.invites.length, 1);
    assert.equal(payload.invites[0].id, 66);
    assert.equal(payload.invites[0].target_user_id, 'target-1');
    assert.equal(payload.invites[0].target_nome, 'Mario');
    assert.equal(payload.invites[0].target_cognome, 'Rossi');
    assert.equal(payload.invites[0].club.id, 1);
    assert.equal(payload.invites[0].club.name, 'Club Uno');
    assert.equal(payload.invites[0].club.slug, 'club-uno');
    assert.equal(payload.invites[0].club.logo_storage_path, undefined);
    assert.equal(payload.invites[0].club.created_by_user_id, undefined);
    assert.equal(payload.invites[0].club.created_at, undefined);
    assert.equal(payload.invites[0].club.updated_at, undefined);
  });
});

test('GET /club-invites/sent keeps invite target fields and returns sanitized nested club data', async () => {
  const invite = createInvite({
    id: 67,
    target_user_id: 'target-2',
    target_account_email: 'target-2@example.com',
    target_nome: 'Luigi',
    target_cognome: 'Verdi',
    target_id_console: 'luigi-10',
    target_primary_role: 'ATT',
    status: 'pending',
    club: {
      ...createClub(),
      logo_storage_path: 'clubs/1/logo.png',
      created_by_user_id: 'captain-1',
      created_at: '2026-05-04T10:00:00.000Z',
      updated_at: '2026-05-04T10:00:00.000Z',
    },
  });

  const router = createClubInvitesRouter({
    db: new FakeSupabaseClient({
      club_invites: [invite],
    }) as any,
    authMiddleware: authAs(buildPrincipal(true)),
  });

  await withTestServer(router, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/sent?status=all`);

    assert.equal(response.status, 200);
    const payload = await response.json();
    assert.equal(payload.invites.length, 1);
    assert.equal(payload.invites[0].id, 67);
    assert.equal(payload.invites[0].status, 'pending');
    assert.equal(payload.invites[0].target_user_id, 'target-2');
    assert.equal(payload.invites[0].target_nome, 'Luigi');
    assert.equal(payload.invites[0].target_cognome, 'Verdi');
    assert.equal(payload.invites[0].target_id_console, 'luigi-10');
    assert.equal(payload.invites[0].target_primary_role, 'ATT');
    assert.equal(payload.invites[0].club.id, 1);
    assert.equal(payload.invites[0].club.name, 'Club Uno');
    assert.equal(payload.invites[0].club.logo_storage_path, undefined);
    assert.equal(payload.invites[0].club.created_by_user_id, undefined);
    assert.equal(payload.invites[0].club.created_at, undefined);
    assert.equal(payload.invites[0].club.updated_at, undefined);
  });
});

test('POST /club-invites/:id/accept returns membership data and publishes expanded scopes', async () => {
  const published: Array<{ scopes: string[]; reason: string }> = [];
  const db = Object.assign(
    new FakeSupabaseClient({
      club_invites: [
        createInvite({
          id: 77,
          target_user_id: 'target-1',
          status: 'accepted',
          accepted_membership_id: 300,
          accepted_player_id: 400,
        }),
      ],
      memberships: [
        {
          id: 300,
          club_id: 1,
          auth_user_id: 'target-1',
          role: 'player',
          status: 'active',
          left_at: null,
          created_at: '2026-05-04T10:00:00.000Z',
          updated_at: '2026-05-04T10:00:00.000Z',
        },
      ],
      player_profiles: [
        {
          id: 400,
          club_id: 1,
          membership_id: 300,
          nome: 'Mario',
          cognome: 'Rossi',
          auth_user_id: 'target-1',
          account_email: 'target@example.com',
          shirt_number: 9,
          primary_role: 'ATT',
          secondary_role: null,
          secondary_roles: [],
          id_console: 'mario-console',
          team_role: 'player',
          archived_at: null,
          created_at: '2026-05-04T10:00:00.000Z',
          updated_at: '2026-05-04T10:00:00.000Z',
        },
      ],
    }),
    {
      rpc: async () => ({
        data: {
          invite_id: 77,
          club_id: 1,
          membership_id: 300,
          player_id: 400,
          status: 'accepted',
        },
        error: null,
      }),
    },
  );

  const principal: RequestPrincipal = {
    ...buildPrincipal(false),
    authUser: {
      id: 'target-1',
      email: 'target@example.com',
      emailVerified: true,
      emailVerifiedAt: '2026-05-04T09:00:00.000Z',
    },
    club: null,
    membership: null,
    hasClub: false,
    isCaptain: false,
    canManageInvites: false,
  };

  const router = createClubInvitesRouter({
    db: db as any,
    authMiddleware: authAs(principal),
    publishChange: (scopes, reason = 'updated') => {
      published.push({ scopes, reason });
      return null as any;
    },
  });

  await withTestServer(router, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/77/accept`, {
      method: 'POST',
    });

    assert.equal(response.status, 200);
    const payload = await response.json();
    assert.equal(payload.invite.id, 77);
    assert.equal(payload.membership.id, 300);
    assert.equal(payload.player.id, 400);
  });

  assert.deepEqual(published, [
    {
      scopes: ['invites', 'notifications', 'players', 'clubs'],
      reason: 'club_invite_accepted',
    },
  ]);
});
