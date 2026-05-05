import assert from 'node:assert/strict';
import test from 'node:test';

import type {
  ClubInviteRow,
  ClubRow,
  MembershipRow,
  PlayerProfileRow,
  RequestPrincipal,
  VicePermissionsRow,
} from '../domain/types';
import { ConflictError, ForbiddenError } from '../lib/errors';
import { InvitesService } from '../services/invites.service';
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
    created_at: '2026-05-04T10:00:00.000Z',
    updated_at: '2026-05-04T10:00:00.000Z',
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
    created_at: '2026-05-04T10:00:00.000Z',
    updated_at: '2026-05-04T10:00:00.000Z',
    ...overrides,
  };
}

function createPermissions(
  clubId: string | number,
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
    updated_at: '2026-05-04T10:00:00.000Z',
    ...overrides,
  };
}

function createPlayerProfile(overrides: Partial<PlayerProfileRow> = {}): PlayerProfileRow {
  return {
    id: 100,
    club_id: null,
    membership_id: null,
    nome: 'Mario',
    cognome: 'Rossi',
    auth_user_id: 'target-1',
    account_email: 'target-1@example.com',
    shirt_number: 10,
    primary_role: 'ATT',
    secondary_role: null,
    secondary_roles: [],
    id_console: 'target-1-console',
    team_role: 'player',
    archived_at: null,
    created_at: '2026-05-04T10:00:00.000Z',
    updated_at: '2026-05-04T10:00:00.000Z',
    ...overrides,
  };
}

function createInvite(overrides: Partial<ClubInviteRow> = {}): ClubInviteRow {
  return {
    id: 500,
    club_id: 1,
    created_by_user_id: 'captain-1',
    created_by_membership_id: 10,
    target_user_id: 'target-1',
    target_player_profile_id: 100,
    target_account_email: 'target-1@example.com',
    target_nome: 'Mario',
    target_cognome: 'Rossi',
    target_id_console: 'target-1-console',
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

function buildPrincipal(options: {
  userId: string;
  club?: ClubRow | null;
  membership?: MembershipRow | null;
  permissions?: Partial<VicePermissionsRow>;
}): RequestPrincipal {
  const membership = options.membership ?? null;
  const club = options.club ?? null;
  const role = membership?.role ?? 'player';
  const isCaptain = role === 'captain';
  const isViceCaptain = role === 'vice_captain';
  const permissions = createPermissions(membership?.club_id ?? club?.id ?? 0, options.permissions);

  return {
    authUser: {
      id: options.userId,
      email: `${options.userId}@example.com`,
      emailVerified: true,
      emailVerifiedAt: '2026-05-04T09:00:00.000Z',
    },
    club,
    membership,
    player: null,
    permissions,
    isCaptain,
    isViceCaptain,
    hasClub: membership != null && club != null,
    canManagePlayers: false,
    canManageLineups: false,
    canManageStreams: false,
    canManageAttendance: false,
    canManageInvites: isCaptain || (isViceCaptain && permissions.vice_manage_invites),
    canManageClubInfo: false,
  };
}

test('listCandidates excludes active memberships and pending invites while surfacing pending join reasons', async () => {
  const club = createClub();
  const captainMembership = createMembership();
  const db = new FakeSupabaseClient({
    player_profiles: [
      createPlayerProfile({
        id: 100,
        auth_user_id: 'candidate-open',
        nome: 'Open',
        cognome: 'Candidate',
        account_email: 'open@example.com',
      }),
      createPlayerProfile({
        id: 101,
        auth_user_id: 'candidate-active',
        nome: 'Active',
        cognome: 'Candidate',
        account_email: 'active@example.com',
      }),
      createPlayerProfile({
        id: 102,
        auth_user_id: 'candidate-pending-invite',
        nome: 'PendingInvite',
        cognome: 'Candidate',
        account_email: 'pending-invite@example.com',
      }),
      createPlayerProfile({
        id: 103,
        auth_user_id: 'candidate-join-same',
        nome: 'JoinSame',
        cognome: 'Candidate',
        account_email: 'join-same@example.com',
      }),
      createPlayerProfile({
        id: 104,
        auth_user_id: 'candidate-join-other',
        nome: 'JoinOther',
        cognome: 'Candidate',
        account_email: 'join-other@example.com',
      }),
    ],
    memberships: [
      captainMembership,
      createMembership({
        id: 11,
        auth_user_id: 'candidate-active',
        role: 'player',
      }),
    ],
    club_invites: [
      createInvite({
        id: 700,
        target_user_id: 'candidate-pending-invite',
        target_player_profile_id: 102,
        target_account_email: 'pending-invite@example.com',
        target_nome: 'PendingInvite',
        target_cognome: 'Candidate',
      }),
    ],
    join_requests: [
      {
        id: 800,
        club_id: 1,
        requester_user_id: 'candidate-join-same',
        requester_email: 'join-same@example.com',
        requested_nome: 'JoinSame',
        requested_cognome: 'Candidate',
        requested_shirt_number: null,
        requested_primary_role: null,
        status: 'pending',
        decided_by_membership_id: null,
        decided_at: null,
        cancelled_at: null,
        expires_at: null,
        created_at: '2026-05-04T10:00:00.000Z',
        updated_at: '2026-05-04T10:00:00.000Z',
      },
      {
        id: 801,
        club_id: 99,
        requester_user_id: 'candidate-join-other',
        requester_email: 'join-other@example.com',
        requested_nome: 'JoinOther',
        requested_cognome: 'Candidate',
        requested_shirt_number: null,
        requested_primary_role: null,
        status: 'pending',
        decided_by_membership_id: null,
        decided_at: null,
        cancelled_at: null,
        expires_at: null,
        created_at: '2026-05-04T10:00:00.000Z',
        updated_at: '2026-05-04T10:00:00.000Z',
      },
    ],
  });

  const service = new InvitesService(db as any);
  const candidates = await service.listCandidates(
    {
      q: 'Candidate',
      limit: 20,
    },
    buildPrincipal({
      userId: 'captain-1',
      club,
      membership: captainMembership,
    }),
  );

  assert.deepEqual(
    candidates.map((candidate) => ({
      userId: candidate.user_id,
      invitable: candidate.invitable,
      reason: candidate.reason,
    })),
    [
      {
        userId: 'candidate-open',
        invitable: true,
        reason: null,
      },
      {
        userId: 'candidate-join-other',
        invitable: false,
        reason: 'pending_join_request_other_club',
      },
      {
        userId: 'candidate-join-same',
        invitable: false,
        reason: 'pending_join_request_same_club',
      },
    ],
  );
});

test('createInvite rejects principals without canManageInvites', async () => {
  const service = new InvitesService(new FakeSupabaseClient() as any);

  await assert.rejects(
    () =>
      service.createInvite(
        { targetUserId: '00000000-0000-0000-0000-000000000001' },
        buildPrincipal({
          userId: 'player-1',
          club: createClub(),
          membership: createMembership({
            auth_user_id: 'player-1',
            role: 'player',
          }),
        }),
      ),
    ForbiddenError,
  );
});

test('createInvite maps duplicate invite conflict from RPC', async () => {
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
  const service = new InvitesService(db as any);

  await assert.rejects(
    () =>
      service.createInvite(
        { targetUserId: '00000000-0000-0000-0000-000000000001' },
        buildPrincipal({
          userId: 'captain-1',
          club: createClub(),
          membership: createMembership(),
        }),
      ),
    (error: unknown) =>
      error instanceof ConflictError && error.code === 'pending_club_invite_exists',
  );
});

test('acceptInvite returns invite membership and player resolved after RPC success', async () => {
  const invite = createInvite({
    id: 501,
    target_user_id: 'target-accept',
    target_player_profile_id: 201,
    target_account_email: 'target-accept@example.com',
    target_nome: 'Target',
    target_cognome: 'Accept',
    accepted_membership_id: 33,
    accepted_player_id: 201,
    status: 'accepted',
  });
  const membership = createMembership({
    id: 33,
    club_id: 1,
    auth_user_id: 'target-accept',
    role: 'player',
  });
  const player = createPlayerProfile({
    id: 201,
    club_id: 1,
    membership_id: 33,
    auth_user_id: 'target-accept',
    nome: 'Target',
    cognome: 'Accept',
    account_email: 'target-accept@example.com',
  });
  const db = Object.assign(
    new FakeSupabaseClient({
      club_invites: [invite],
      memberships: [membership],
      player_profiles: [player],
    }),
    {
      rpc: async () => ({
        data: {
          invite_id: 501,
          club_id: 1,
          membership_id: 33,
          player_id: 201,
          status: 'accepted',
        },
        error: null,
      }),
    },
  );

  const service = new InvitesService(db as any);
  const result = await service.acceptInvite(
    501,
    buildPrincipal({
      userId: 'target-accept',
    }),
  );

  assert.equal(result.invite.id, 501);
  assert.equal(result.membership.id, 33);
  assert.equal(result.player.id, 201);
});

test('declineInvite returns the updated invite from RPC', async () => {
  const invite = createInvite({
    id: 502,
    target_user_id: 'target-decline',
    status: 'declined',
    resolved_at: '2026-05-04T11:00:00.000Z',
    resolved_by_user_id: 'target-decline',
  });
  const db = Object.assign(
    new FakeSupabaseClient({
      club_invites: [invite],
    }),
    {
      rpc: async () => ({
        data: {
          invite_id: 502,
          status: 'declined',
        },
        error: null,
      }),
    },
  );

  const service = new InvitesService(db as any);
  const result = await service.declineInvite(
    502,
    buildPrincipal({
      userId: 'target-decline',
    }),
  );

  assert.equal(result.status, 'declined');
});

test('revokeInvite returns the updated invite from RPC', async () => {
  const invite = createInvite({
    id: 503,
    status: 'revoked',
    resolved_at: '2026-05-04T11:00:00.000Z',
    resolved_by_user_id: 'captain-1',
    resolved_by_membership_id: 10,
  });
  const db = Object.assign(
    new FakeSupabaseClient({
      club_invites: [invite],
    }),
    {
      rpc: async () => ({
        data: {
          invite_id: 503,
          status: 'revoked',
        },
        error: null,
      }),
    },
  );

  const service = new InvitesService(db as any);
  const result = await service.revokeInvite(
    503,
    buildPrincipal({
      userId: 'captain-1',
      club: createClub(),
      membership: createMembership(),
    }),
  );

  assert.equal(result.status, 'revoked');
});
