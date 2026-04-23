import assert from 'node:assert/strict';
import test from 'node:test';

import type {
  ClubRow,
  LeaveRequestRow,
  MembershipRow,
  PlayerProfileRow,
  RequestPrincipal,
  TeamRole,
  VicePermissionsRow,
} from '../domain/types';
import { ConflictError, ForbiddenError } from '../lib/errors';
import { ClubsService } from '../services/clubs.service';
import { PlayerService } from '../services/player.service';
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
    id: 1,
    club_id: 1,
    auth_user_id: 'user-1',
    role: 'player',
    status: 'active',
    left_at: null,
    created_at: '2026-04-20T10:00:00.000Z',
    updated_at: '2026-04-20T10:00:00.000Z',
    ...overrides,
  };
}

function createPlayerProfile(overrides: Partial<PlayerProfileRow> = {}): PlayerProfileRow {
  return {
    id: 1,
    club_id: 1,
    membership_id: null,
    nome: 'Mario',
    cognome: 'Rossi',
    auth_user_id: null,
    account_email: null,
    shirt_number: 10,
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
    updated_at: '2026-04-20T10:00:00.000Z',
    ...overrides,
  };
}

function buildPrincipal(options: {
  userId: string;
  email?: string;
  emailVerified?: boolean;
  club?: ClubRow | null;
  membership?: MembershipRow | null;
  player?: PlayerProfileRow | null;
  permissions?: Partial<VicePermissionsRow>;
}): RequestPrincipal {
  const membership = options.membership ?? null;
  const club = options.club ?? null;
  const role = membership?.role ?? 'player';
  const isCaptain = role === 'captain';
  const isViceCaptain = role === 'vice_captain';
  const permissions = createPermissions(
    membership?.club_id ?? club?.id ?? 0,
    options.permissions,
  );

  return {
    authUser: {
      id: options.userId,
      email: options.email ?? `${options.userId}@example.com`,
      emailVerified: options.emailVerified ?? true,
      emailVerifiedAt:
        options.emailVerified ?? true ? '2026-04-20T09:00:00.000Z' : null,
    },
    club,
    membership,
    player: options.player ?? null,
    permissions,
    isCaptain,
    isViceCaptain,
    hasClub: membership != null && club != null,
    canManagePlayers: isCaptain || (isViceCaptain && permissions.vice_manage_players),
    canManageLineups: isCaptain || (isViceCaptain && permissions.vice_manage_lineups),
    canManageStreams: isCaptain || (isViceCaptain && permissions.vice_manage_streams),
    canManageAttendance: isCaptain || (isViceCaptain && permissions.vice_manage_attendance),
    canManageTeamInfo: isCaptain || (isViceCaptain && permissions.vice_manage_team_info),
  };
}

function createClubSeed(options?: {
  clubId?: number;
  clubName?: string;
  captainUserId?: string;
  captainMembershipId?: number;
}): {
  club: ClubRow;
  captainMembership: MembershipRow;
  captainPlayer: PlayerProfileRow;
} {
  const clubId = options?.clubId ?? 1;
  const captainUserId = options?.captainUserId ?? `captain-${clubId}`;
  const captainMembershipId = options?.captainMembershipId ?? clubId * 10;
  const clubName = options?.clubName ?? `Club ${clubId}`;

  const club = createClub({
    id: clubId,
    name: clubName,
    normalized_name: clubName.toLowerCase(),
    slug: clubName.toLowerCase().replaceAll(' ', '-'),
    created_by_user_id: captainUserId,
  });
  const captainMembership = createMembership({
    id: captainMembershipId,
    club_id: clubId,
    auth_user_id: captainUserId,
    role: 'captain',
  });
  const captainPlayer = createPlayerProfile({
    id: clubId * 100,
    club_id: clubId,
    membership_id: captainMembershipId,
    auth_user_id: captainUserId,
    account_email: `${captainUserId}@example.com`,
    nome: 'Captain',
    cognome: `${clubId}`,
    team_role: 'captain',
  });

  return {
    club,
    captainMembership,
    captainPlayer,
  };
}

test('createClub creates the club, captain membership, player profile, and defaults', async () => {
  const db = new FakeSupabaseClient();
  const service = new ClubsService(db as any);

  const result = await service.createClub(
    {
      name: 'Clubline Roma',
      owner_nome: 'Ciro',
      owner_cognome: 'Saraino',
      owner_id_console: 'ciro10',
    },
    buildPrincipal({
      userId: 'founder-1',
      email: 'founder@example.com',
    }),
  );

  assert.equal(result.club.name, 'Clubline Roma');
  assert.equal(result.club.normalized_name, 'clubline roma');
  assert.equal(result.club.slug, 'clubline-roma');
  assert.equal(result.membership.role, 'captain');

  const clubs = db.rows<ClubRow>('clubs');
  const memberships = db.rows<MembershipRow>('memberships');
  const players = db.rows<PlayerProfileRow>('player_profiles');

  assert.equal(clubs.length, 1);
  assert.equal(memberships.length, 1);
  assert.equal(players.length, 1);
  assert.equal(players[0]?.membership_id, memberships[0]?.id);
  assert.equal(players[0]?.team_role, 'captain');
  assert.equal(players[0]?.id_console, 'ciro10');
  assert.equal(db.rows('club_settings').length, 1);
  assert.equal(db.rows('club_permission_settings').length, 1);
});

test('createClub rejects duplicate club names with case-insensitive normalization', async () => {
  const db = new FakeSupabaseClient({
    clubs: [
      createClub({
        id: 1,
        name: 'Clubline Roma',
        normalized_name: 'clubline roma',
        slug: 'clubline-roma',
      }),
    ],
  });
  const service = new ClubsService(db as any);

  await assert.rejects(
    () =>
      service.createClub(
        {
          name: '  CLUBLINE   roma ',
          owner_nome: 'Mario',
          owner_cognome: 'Bianchi',
          owner_id_console: 'mario-bia',
        },
        buildPrincipal({ userId: 'founder-2' }),
      ),
    ConflictError,
  );
});

test('listClubs uses prefix search and paginates club discovery results', async () => {
  const db = new FakeSupabaseClient({
    clubs: [
      createClub({
        id: 1,
        name: 'Napoli',
        normalized_name: 'napoli',
        slug: 'napoli',
      }),
      createClub({
        id: 2,
        name: 'Napster FC',
        normalized_name: 'napster fc',
        slug: 'napster-fc',
      }),
      createClub({
        id: 3,
        name: 'Roma',
        normalized_name: 'roma',
        slug: 'roma',
      }),
    ],
  });
  const service = new ClubsService(db as any);

  const firstPage = await service.listClubs({
    search: 'nap',
    page: 1,
    limit: 1,
  });

  assert.equal(firstPage.clubs.length, 1);
  assert.equal(firstPage.clubs[0]?.name, 'Napoli');
  assert.equal(firstPage.pagination.hasMore, true);
  assert.equal(firstPage.pagination.nextPage, 2);
  assert.equal(firstPage.pagination.query, 'nap');

  const secondPage = await service.listClubs({
    search: 'nap',
    page: 2,
    limit: 1,
  });

  assert.equal(secondPage.clubs.length, 1);
  assert.equal(secondPage.clubs[0]?.name, 'Napster FC');
  assert.equal(secondPage.pagination.hasMore, false);
  assert.equal(secondPage.pagination.nextPage, null);
});

test('requestJoinClub creates a pending request and captain approval activates membership', async () => {
  const seed = createClubSeed({ clubId: 1 });
  const db = new FakeSupabaseClient({
    clubs: [seed.club],
    memberships: [seed.captainMembership],
    player_profiles: [seed.captainPlayer],
  });
  const service = new ClubsService(db as any);

  const joinRequest = await service.requestJoinClub(
    {
      club_id: seed.club.id,
      requested_nome: 'Luca',
      requested_cognome: 'Verdi',
      requested_shirt_number: 7,
      requested_primary_role: 'CC',
    },
    buildPrincipal({
      userId: 'player-join-1',
      email: 'luca@example.com',
    }),
  );

  assert.equal(joinRequest.status, 'pending');

  const membership = await service.approveJoinRequest(
    joinRequest.id,
    buildPrincipal({
      userId: seed.captainMembership.auth_user_id,
      club: seed.club,
      membership: seed.captainMembership,
      player: seed.captainPlayer,
    }),
  );

  assert.equal(membership.club_id, seed.club.id);
  assert.equal(membership.role, 'player');

  const requests = db.rows<any>('join_requests');
  const joinedPlayers = db
    .rows<PlayerProfileRow>('player_profiles')
    .filter((player) => player.auth_user_id === 'player-join-1');

  assert.equal(requests[0]?.status, 'approved');
  assert.equal(joinedPlayers.length, 1);
  assert.equal(joinedPlayers[0]?.membership_id, membership.id);
  assert.equal(joinedPlayers[0]?.team_role, 'player');
});

test('join approval self-heals a stale active membership if an approved leave already exists', async () => {
  const clubOne = createClubSeed({ clubId: 1 });
  const clubTwo = createClubSeed({ clubId: 2 });
  const staleMembership = createMembership({
    id: 31,
    club_id: clubOne.club.id,
    auth_user_id: 'player-returning-1',
    role: 'player',
    status: 'active',
  });
  const staleProfile = createPlayerProfile({
    id: 131,
    club_id: clubOne.club.id,
    membership_id: staleMembership.id,
    auth_user_id: staleMembership.auth_user_id,
    account_email: 'player-returning-1@example.com',
    team_role: 'player',
  });
  const approvedLeave: LeaveRequestRow = {
    id: 41,
    club_id: clubOne.club.id,
    membership_id: staleMembership.id,
    requested_by_user_id: staleMembership.auth_user_id,
    status: 'approved',
    decided_by_membership_id: clubOne.captainMembership.id,
    decided_at: '2026-04-21T12:00:00.000Z',
    cancelled_at: null,
    expires_at: null,
    created_at: '2026-04-21T11:55:00.000Z',
  };
  const joinRequest = {
    id: 42,
    club_id: clubTwo.club.id,
    requester_user_id: staleMembership.auth_user_id,
    requester_email: 'player-returning-1@example.com',
    requested_nome: 'Luca',
    requested_cognome: 'Rientro',
    requested_shirt_number: 19,
    requested_primary_role: 'CDC',
    status: 'pending',
    decided_by_membership_id: null,
    decided_at: null,
    cancelled_at: null,
    expires_at: null,
    created_at: '2026-04-21T12:10:00.000Z',
  };

  const db = new FakeSupabaseClient({
    clubs: [clubOne.club, clubTwo.club],
    memberships: [
      clubOne.captainMembership,
      clubTwo.captainMembership,
      staleMembership,
    ],
    player_profiles: [
      clubOne.captainPlayer,
      clubTwo.captainPlayer,
      staleProfile,
    ],
    leave_requests: [approvedLeave],
    join_requests: [joinRequest],
  });
  const service = new ClubsService(db as any);

  const membership = await service.approveJoinRequest(
    joinRequest.id,
    buildPrincipal({
      userId: clubTwo.captainMembership.auth_user_id,
      club: clubTwo.club,
      membership: clubTwo.captainMembership,
      player: clubTwo.captainPlayer,
    }),
  );

  const memberships = db.rows<MembershipRow>('memberships');
  const repairedMembership = memberships.find(
    (candidate) => candidate.id === staleMembership.id,
  );
  const newMembership = memberships.find(
    (candidate) => `${candidate.id}` === `${membership.id}`,
  );
  const profilesForReturningUser = db
    .rows<PlayerProfileRow>('player_profiles')
    .filter((candidate) => candidate.auth_user_id === staleMembership.auth_user_id);
  const reattachedProfile = profilesForReturningUser[0] ?? null;

  assert.equal(repairedMembership?.status, 'left');
  assert.notEqual(repairedMembership?.left_at, null);
  assert.equal(newMembership?.club_id, clubTwo.club.id);
  assert.equal(newMembership?.status, 'active');
  assert.equal(newMembership?.auth_user_id, staleMembership.auth_user_id);
  assert.equal(profilesForReturningUser.length, 1);
  assert.equal(reattachedProfile?.club_id, clubTwo.club.id);
  assert.equal(reattachedProfile?.membership_id, membership.id);
});

test('join request approvals are captain-only and captains can reject pending requests', async () => {
  const seed = createClubSeed({ clubId: 1 });
  const playerMembership = createMembership({
    id: 11,
    club_id: seed.club.id,
    auth_user_id: 'member-1',
    role: 'player',
  });
  const playerProfile = createPlayerProfile({
    id: 101,
    club_id: seed.club.id,
    membership_id: playerMembership.id,
    auth_user_id: playerMembership.auth_user_id,
    account_email: 'member-1@example.com',
  });
  const joinRequest = {
    id: 1,
    club_id: seed.club.id,
    requester_user_id: 'candidate-1',
    requester_email: 'candidate-1@example.com',
    requested_nome: 'Paolo',
    requested_cognome: 'Neri',
    requested_shirt_number: null,
    requested_primary_role: null,
    status: 'pending',
    decided_by_membership_id: null,
    decided_at: null,
    cancelled_at: null,
    expires_at: null,
  };

  const db = new FakeSupabaseClient({
    clubs: [seed.club],
    memberships: [seed.captainMembership, playerMembership],
    player_profiles: [seed.captainPlayer, playerProfile],
    join_requests: [joinRequest],
  });
  const service = new ClubsService(db as any);

  await assert.rejects(
    () =>
      service.approveJoinRequest(
        joinRequest.id,
        buildPrincipal({
          userId: playerMembership.auth_user_id,
          club: seed.club,
          membership: playerMembership,
          player: playerProfile,
        }),
      ),
    ForbiddenError,
  );

  await service.rejectJoinRequest(
    joinRequest.id,
    buildPrincipal({
      userId: seed.captainMembership.auth_user_id,
      club: seed.club,
      membership: seed.captainMembership,
      player: seed.captainPlayer,
    }),
  );

  assert.equal(db.rows<any>('join_requests')[0]?.status, 'rejected');
});

test('requestJoinClub enforces the one-active-club-per-user rule', async () => {
  const clubOne = createClubSeed({ clubId: 1 });
  const clubTwo = createClubSeed({ clubId: 2 });
  const existingMembership = createMembership({
    id: 30,
    club_id: clubOne.club.id,
    auth_user_id: 'member-locked',
    role: 'player',
  });

  const db = new FakeSupabaseClient({
    clubs: [clubOne.club, clubTwo.club],
    memberships: [clubOne.captainMembership, clubTwo.captainMembership, existingMembership],
    player_profiles: [clubOne.captainPlayer, clubTwo.captainPlayer],
  });
  const service = new ClubsService(db as any);

  await assert.rejects(
    () =>
      service.requestJoinClub(
        {
          club_id: clubTwo.club.id,
          requested_nome: 'Marco',
          requested_cognome: 'Blu',
        },
        buildPrincipal({
          userId: 'member-locked',
          club: clubOne.club,
          membership: existingMembership,
        }),
      ),
    ConflictError,
  );
});

test('members can request leave and captain approval detach the profile but keep the player identity', async () => {
  const seed = createClubSeed({ clubId: 1 });
  const memberMembership = createMembership({
    id: 12,
    club_id: seed.club.id,
    auth_user_id: 'leaving-member',
    role: 'player',
  });
  const memberProfile = createPlayerProfile({
    id: 102,
    club_id: seed.club.id,
    membership_id: memberMembership.id,
    auth_user_id: memberMembership.auth_user_id,
    account_email: 'leaving-member@example.com',
    team_role: 'player',
  });
  const db = new FakeSupabaseClient({
    clubs: [seed.club],
    memberships: [seed.captainMembership, memberMembership],
    player_profiles: [seed.captainPlayer, memberProfile],
  });
  const service = new ClubsService(db as any);

  const leaveRequest = await service.requestLeaveClub(
    buildPrincipal({
      userId: memberMembership.auth_user_id,
      club: seed.club,
      membership: memberMembership,
      player: memberProfile,
    }),
  );

  assert.equal(leaveRequest.status, 'pending');

  await service.approveLeaveRequest(
    leaveRequest.id,
    buildPrincipal({
      userId: seed.captainMembership.auth_user_id,
      club: seed.club,
      membership: seed.captainMembership,
      player: seed.captainPlayer,
    }),
  );

  const memberships = db.rows<MembershipRow>('memberships');
  const players = db.rows<PlayerProfileRow>('player_profiles');
  const updatedMembership = memberships.find((membership) => membership.id === memberMembership.id);
  const updatedProfile = players.find((player) => player.id === memberProfile.id);

  assert.equal(db.rows<any>('leave_requests')[0]?.status, 'approved');
  assert.equal(updatedMembership?.status, 'left');
  assert.notEqual(updatedMembership?.left_at, null);
  assert.equal(updatedProfile?.club_id, null);
  assert.equal(updatedProfile?.membership_id, null);
  assert.equal(updatedProfile?.auth_user_id, memberMembership.auth_user_id);
  assert.equal(updatedProfile?.account_email, 'leaving-member@example.com');
  assert.equal(updatedProfile?.archived_at, null);
});

test('captains can reject leave requests and cannot leave until the role is transferred', async () => {
  const seed = createClubSeed({ clubId: 1 });
  const memberMembership = createMembership({
    id: 13,
    club_id: seed.club.id,
    auth_user_id: 'staying-member',
    role: 'player',
  });
  const memberProfile = createPlayerProfile({
    id: 103,
    club_id: seed.club.id,
    membership_id: memberMembership.id,
    auth_user_id: memberMembership.auth_user_id,
    account_email: 'staying-member@example.com',
  });
  const pendingLeave = {
    id: 1,
    club_id: seed.club.id,
    membership_id: memberMembership.id,
    requested_by_user_id: memberMembership.auth_user_id,
    status: 'pending',
    decided_by_membership_id: null,
    decided_at: null,
    cancelled_at: null,
    expires_at: null,
  };

  const db = new FakeSupabaseClient({
    clubs: [seed.club],
    memberships: [seed.captainMembership, memberMembership],
    player_profiles: [seed.captainPlayer, memberProfile],
    leave_requests: [pendingLeave],
  });
  const service = new ClubsService(db as any);
  const captainPrincipal = buildPrincipal({
    userId: seed.captainMembership.auth_user_id,
    club: seed.club,
    membership: seed.captainMembership,
    player: seed.captainPlayer,
  });

  await assert.rejects(
    () => service.requestLeaveClub(captainPrincipal),
    ConflictError,
  );

  await service.rejectLeaveRequest(pendingLeave.id, captainPrincipal);

  assert.equal(db.rows<any>('leave_requests')[0]?.status, 'rejected');
});

test('captains can list pending leave requests with membership details', async () => {
  const seed = createClubSeed({ clubId: 1 });
  const memberMembership = createMembership({
    id: 14,
    club_id: seed.club.id,
    auth_user_id: 'pending-leaver',
    role: 'player',
  });
  const pendingLeave: LeaveRequestRow = {
    id: 2,
    club_id: seed.club.id,
    membership_id: memberMembership.id,
    requested_by_user_id: memberMembership.auth_user_id,
    status: 'pending',
    decided_by_membership_id: null,
    decided_at: null,
    cancelled_at: null,
    expires_at: null,
  };

  const db = new FakeSupabaseClient({
    clubs: [seed.club],
    memberships: [seed.captainMembership, memberMembership],
    player_profiles: [seed.captainPlayer],
    leave_requests: [pendingLeave],
  });
  const service = new ClubsService(db as any);

  const requests = await service.listPendingLeaveRequests(
    buildPrincipal({
      userId: seed.captainMembership.auth_user_id,
      club: seed.club,
      membership: seed.captainMembership,
      player: seed.captainPlayer,
    }),
  );

  assert.equal(requests.length, 1);
  assert.equal(requests[0]?.membership?.id, memberMembership.id);
  assert.equal(requests[0]?.membership?.auth_user_id, memberMembership.auth_user_id);
});

test('captains can release a player from the club without deleting the identity', async () => {
  const seed = createClubSeed({ clubId: 1 });
  const memberMembership = createMembership({
    id: 15,
    club_id: seed.club.id,
    auth_user_id: 'released-member',
    role: 'player',
  });
  const memberProfile = createPlayerProfile({
    id: 105,
    club_id: seed.club.id,
    membership_id: memberMembership.id,
    auth_user_id: memberMembership.auth_user_id,
    account_email: 'released-member@example.com',
    shirt_number: 8,
    primary_role: 'CDC',
    secondary_role: 'CC',
    secondary_roles: ['CC'],
    id_console: 'released-8',
    team_role: 'player',
  });

  const db = new FakeSupabaseClient({
    clubs: [seed.club],
    memberships: [seed.captainMembership, memberMembership],
    player_profiles: [seed.captainPlayer, memberProfile],
  });
  const service = new PlayerService(db as any);

  await service.releasePlayerFromClub(
    memberProfile.id,
    buildPrincipal({
      userId: seed.captainMembership.auth_user_id,
      club: seed.club,
      membership: seed.captainMembership,
      player: seed.captainPlayer,
    }),
  );

  const updatedMembership = db
    .rows<MembershipRow>('memberships')
    .find((membership) => membership.id === memberMembership.id);
  const updatedProfile = db
    .rows<PlayerProfileRow>('player_profiles')
    .find((player) => player.id === memberProfile.id);

  assert.equal(updatedMembership?.status, 'left');
  assert.notEqual(updatedMembership?.left_at, null);
  assert.equal(updatedProfile?.club_id, null);
  assert.equal(updatedProfile?.membership_id, null);
  assert.equal(updatedProfile?.auth_user_id, memberMembership.auth_user_id);
  assert.equal(updatedProfile?.account_email, 'released-member@example.com');
  assert.equal(updatedProfile?.shirt_number, 8);
  assert.equal(updatedProfile?.primary_role, 'CDC');
  assert.deepEqual(updatedProfile?.secondary_roles, ['CC']);
  assert.equal(updatedProfile?.id_console, 'released-8');
  assert.equal(updatedProfile?.team_role, 'player');
  assert.equal(updatedProfile?.archived_at, null);
});

test('releasing a player with lineup or attendance history archives the old club row and creates a standalone copy', async () => {
  const seed = createClubSeed({ clubId: 1 });
  const memberMembership = createMembership({
    id: 17,
    club_id: seed.club.id,
    auth_user_id: 'historic-member',
    role: 'player',
  });
  const memberProfile = createPlayerProfile({
    id: 117,
    club_id: seed.club.id,
    membership_id: memberMembership.id,
    auth_user_id: memberMembership.auth_user_id,
    account_email: 'historic-member@example.com',
    shirt_number: 21,
    primary_role: 'ATT',
    id_console: 'historic-21',
  });

  const db = new FakeSupabaseClient({
    clubs: [seed.club],
    memberships: [seed.captainMembership, memberMembership],
    player_profiles: [seed.captainPlayer, memberProfile],
    attendance_entries: [
      {
        id: 1,
        club_id: seed.club.id,
        week_id: 100,
        player_id: memberProfile.id,
        attendance_date: '2026-04-22',
        availability: 'yes',
        updated_by_player_id: null,
      },
    ],
  });
  const service = new PlayerService(db as any);

  await service.releasePlayerFromClub(
    memberProfile.id,
    buildPrincipal({
      userId: seed.captainMembership.auth_user_id,
      club: seed.club,
      membership: seed.captainMembership,
      player: seed.captainPlayer,
    }),
  );

  const relatedProfiles = db
    .rows<PlayerProfileRow>('player_profiles')
    .filter((player) => player.account_email === 'historic-member@example.com');
  const archivedHistoryProfile = relatedProfiles.find((player) => player.archived_at != null);
  const standaloneProfile = relatedProfiles.find((player) => player.archived_at == null);

  assert.equal(relatedProfiles.length, 2);
  assert.equal(archivedHistoryProfile?.club_id, seed.club.id);
  assert.equal(archivedHistoryProfile?.membership_id, null);
  assert.notEqual(archivedHistoryProfile?.archived_at, null);
  assert.equal(standaloneProfile?.club_id, null);
  assert.equal(standaloneProfile?.membership_id, null);
  assert.equal(standaloneProfile?.auth_user_id, memberMembership.auth_user_id);
  assert.equal(standaloneProfile?.id_console, 'historic-21');
});

test('captain-created standalone players require at least an email or an ID console anchor', async () => {
  const seed = createClubSeed({ clubId: 1 });
  const db = new FakeSupabaseClient({
    clubs: [seed.club],
    memberships: [seed.captainMembership],
    player_profiles: [seed.captainPlayer],
  });
  const service = new PlayerService(db as any);

  await assert.rejects(
    () =>
      service.createPlayer(
        {
          nome: 'Senza',
          cognome: 'Anchor',
        },
        buildPrincipal({
          userId: seed.captainMembership.auth_user_id,
          club: seed.club,
          membership: seed.captainMembership,
          player: seed.captainPlayer,
        }),
      ),
    ConflictError,
  );
});

test('claimProfile reattaches an existing standalone player identity instead of creating a duplicate', async () => {
  const seed = createClubSeed({ clubId: 1 });
  const memberMembership = createMembership({
    id: 18,
    club_id: seed.club.id,
    auth_user_id: 'standalone-member',
    role: 'player',
  });
  const standaloneProfile = createPlayerProfile({
    id: 118,
    club_id: null,
    membership_id: null,
    auth_user_id: memberMembership.auth_user_id,
    account_email: 'standalone-member@example.com',
    nome: 'Marco',
    cognome: 'Standalone',
    shirt_number: 77,
    primary_role: 'CC',
    secondary_role: 'CDC',
    secondary_roles: ['CDC'],
    id_console: 'standalone-77',
    team_role: 'player',
  });
  const db = new FakeSupabaseClient({
    clubs: [seed.club],
    memberships: [seed.captainMembership, memberMembership],
    player_profiles: [seed.captainPlayer, standaloneProfile],
  });
  const service = new PlayerService(db as any);

  const claimedProfile = await service.claimProfile(
    {
      nome: 'Marco',
      cognome: 'Standalone',
      shirt_number: 11,
      primary_role: 'ATT',
      id_console: 'standalone-77',
    },
    buildPrincipal({
      userId: memberMembership.auth_user_id,
      club: seed.club,
      membership: memberMembership,
      player: null,
    }),
  );

  const profilesForUser = db
    .rows<PlayerProfileRow>('player_profiles')
    .filter((candidate) => candidate.auth_user_id === memberMembership.auth_user_id);

  assert.equal(profilesForUser.length, 1);
  assert.equal(claimedProfile.id, standaloneProfile.id);
  assert.equal(claimedProfile.club_id, seed.club.id);
  assert.equal(claimedProfile.membership_id, memberMembership.id);
  assert.equal(claimedProfile.shirt_number, 11);
  assert.equal(claimedProfile.primary_role, 'ATT');
});

test('join approval rolls back the membership if player association fails', async () => {
  const seed = createClubSeed({ clubId: 1 });
  const conflictingAuthProfile = createPlayerProfile({
    id: 201,
    club_id: null,
    membership_id: null,
    auth_user_id: 'candidate-conflict',
    account_email: 'other-mail@example.com',
    id_console: 'candidate-1',
  });
  const conflictingEmailProfile = createPlayerProfile({
    id: 202,
    club_id: null,
    membership_id: null,
    auth_user_id: null,
    account_email: 'candidate@example.com',
    id_console: 'candidate-2',
  });
  const joinRequest = {
    id: 12,
    club_id: seed.club.id,
    requester_user_id: 'candidate-conflict',
    requester_email: 'candidate@example.com',
    requested_nome: 'Paolo',
    requested_cognome: 'Conflitto',
    requested_shirt_number: null,
    requested_primary_role: null,
    status: 'pending',
    decided_by_membership_id: null,
    decided_at: null,
    cancelled_at: null,
    expires_at: null,
  };
  const db = new FakeSupabaseClient({
    clubs: [seed.club],
    memberships: [seed.captainMembership],
    player_profiles: [seed.captainPlayer, conflictingAuthProfile, conflictingEmailProfile],
    join_requests: [joinRequest],
  });
  const service = new ClubsService(db as any);

  await assert.rejects(
    () =>
      service.approveJoinRequest(
        joinRequest.id,
        buildPrincipal({
          userId: seed.captainMembership.auth_user_id,
          club: seed.club,
          membership: seed.captainMembership,
          player: seed.captainPlayer,
        }),
      ),
    ConflictError,
  );

  const requesterMemberships = db
    .rows<MembershipRow>('memberships')
    .filter((membership) => membership.auth_user_id === 'candidate-conflict');

  assert.equal(requesterMemberships.length, 0);
  assert.equal(db.rows<any>('join_requests')[0]?.status, 'pending');
});

test('captains cannot release the captain profile from the roster', async () => {
  const seed = createClubSeed({ clubId: 1 });
  const db = new FakeSupabaseClient({
    clubs: [seed.club],
    memberships: [seed.captainMembership],
    player_profiles: [seed.captainPlayer],
  });
  const service = new PlayerService(db as any);

  await assert.rejects(
    () =>
      service.releasePlayerFromClub(
        seed.captainPlayer.id,
        buildPrincipal({
          userId: seed.captainMembership.auth_user_id,
          club: seed.club,
          membership: seed.captainMembership,
          player: seed.captainPlayer,
        }),
      ),
    ConflictError,
  );
});

test('deleteCurrentClub self-heals stale active leavers before counting members', async () => {
  const seed = createClubSeed({ clubId: 1 });
  const staleMembership = createMembership({
    id: 16,
    club_id: seed.club.id,
    auth_user_id: 'ghost-member',
    role: 'player',
    status: 'active',
  });
  const staleProfile = createPlayerProfile({
    id: 116,
    club_id: seed.club.id,
    membership_id: staleMembership.id,
    auth_user_id: staleMembership.auth_user_id,
    account_email: 'ghost-member@example.com',
    team_role: 'player',
  });
  const approvedLeave: LeaveRequestRow = {
    id: 17,
    club_id: seed.club.id,
    membership_id: staleMembership.id,
    requested_by_user_id: staleMembership.auth_user_id,
    status: 'approved',
    decided_by_membership_id: seed.captainMembership.id,
    decided_at: '2026-04-21T14:00:00.000Z',
    cancelled_at: null,
    expires_at: null,
    created_at: '2026-04-21T13:55:00.000Z',
  };

  const db = new FakeSupabaseClient({
    clubs: [seed.club],
    memberships: [seed.captainMembership, staleMembership],
    player_profiles: [seed.captainPlayer, staleProfile],
    leave_requests: [approvedLeave],
  });
  const service = new ClubsService(db as any);

  await service.deleteCurrentClub(
    buildPrincipal({
      userId: seed.captainMembership.auth_user_id,
      club: seed.club,
      membership: seed.captainMembership,
      player: seed.captainPlayer,
    }),
  );

  const repairedMembership = db
    .rows<MembershipRow>('memberships')
    .find((candidate) => candidate.id === staleMembership.id);

  assert.equal(db.rows<ClubRow>('clubs').length, 0);
  assert.equal(repairedMembership?.status, 'left');
  assert.notEqual(repairedMembership?.left_at, null);
});

test('player data is isolated by club when listing the roster', async () => {
  const clubOne = createClubSeed({ clubId: 1 });
  const clubTwo = createClubSeed({ clubId: 2 });
  const db = new FakeSupabaseClient({
    clubs: [clubOne.club, clubTwo.club],
    memberships: [clubOne.captainMembership, clubTwo.captainMembership],
    player_profiles: [
      clubOne.captainPlayer,
      clubTwo.captainPlayer,
      createPlayerProfile({
        id: 104,
        club_id: clubOne.club.id,
        nome: 'Active',
        cognome: 'ClubOne',
        team_role: 'player',
        archived_at: null,
      }),
      createPlayerProfile({
        id: 105,
        club_id: clubTwo.club.id,
        nome: 'Hidden',
        cognome: 'ClubTwo',
        team_role: 'player',
        archived_at: null,
      }),
      createPlayerProfile({
        id: 106,
        club_id: clubOne.club.id,
        nome: 'Archived',
        cognome: 'ClubOne',
        team_role: 'player',
        archived_at: '2026-04-20T12:00:00.000Z',
      }),
    ],
  });
  const service = new PlayerService(db as any);

  const players = await service.listPlayers(
    {},
    buildPrincipal({
      userId: clubOne.captainMembership.auth_user_id,
      club: clubOne.club,
      membership: clubOne.captainMembership,
      player: clubOne.captainPlayer,
    }),
  );

  assert.equal(players.every((player) => `${player.club_id}` === `${clubOne.club.id}`), true);
  assert.equal(players.some((player) => player.nome === 'Hidden'), false);
  assert.equal(players.some((player) => player.nome === 'Archived'), false);
  assert.equal(players.some((player) => player.nome === 'Active'), true);
});

test('protected club flows require a verified email address', async () => {
  const db = new FakeSupabaseClient();
  const service = new ClubsService(db as any);

  let thrownError: unknown;
  try {
    await service.createClub(
      {
        name: 'Clubline Napoli',
        owner_nome: 'Anna',
        owner_cognome: 'Rossi',
        owner_id_console: 'anna-rossi',
      },
      buildPrincipal({
        userId: 'unverified-user',
        emailVerified: false,
      }),
    );
  } catch (error) {
    thrownError = error;
  }

  assert.ok(thrownError instanceof ForbiddenError);
});
