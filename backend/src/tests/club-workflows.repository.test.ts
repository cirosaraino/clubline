import assert from 'node:assert/strict';
import test from 'node:test';

import { ClubWorkflowsRepository } from '../repositories/club-workflows.repository';

test('ClubWorkflowsRepository maps createClub RPC payload', async () => {
  let calledFunction = '';
  let calledArgs: Record<string, unknown> | undefined;

  const repository = new ClubWorkflowsRepository({
    rpc: async (fn: string, args?: Record<string, unknown>) => {
      calledFunction = fn;
      calledArgs = args;
      return {
        data: {
          club_id: 11,
          membership_id: 22,
          player_id: 33,
        },
        error: null,
      };
    },
  } as any);

  const result = await repository.createClub({
    actorUserId: 'user-1',
    actorEmail: 'user-1@example.com',
    name: 'Clubline Napoli',
    ownerNome: 'Ciro',
    ownerCognome: 'Saraino',
    ownerConsoleId: 'ciro10',
    ownerShirtNumber: 10,
    ownerPrimaryRole: 'ATT',
    primaryColor: '#0D2C73',
    accentColor: '#10E6CB',
    surfaceColor: '#102247',
  });

  assert.equal(calledFunction, 'clubline_create_club');
  assert.equal(calledArgs?.p_actor_user_id, 'user-1');
  assert.equal(calledArgs?.p_name, 'Clubline Napoli');
  assert.deepEqual(result, {
    clubId: 11,
    membershipId: 22,
    playerId: 33,
  });
});

test('ClubWorkflowsRepository maps approveJoinRequest RPC payload', async () => {
  let calledFunction = '';

  const repository = new ClubWorkflowsRepository({
    rpc: async (fn: string) => {
      calledFunction = fn;
      return {
        data: {
          membership_id: 44,
          player_id: 55,
        },
        error: null,
      };
    },
  } as any);

  const result = await repository.approveJoinRequest({
    actorUserId: 'captain-1',
    joinRequestId: 99,
  });

  assert.equal(calledFunction, 'clubline_approve_join_request');
  assert.deepEqual(result, {
    membershipId: 44,
    playerId: 55,
  });
});

test('ClubWorkflowsRepository maps createClubInvite RPC payload', async () => {
  const repository = new ClubWorkflowsRepository({
    rpc: async () => ({
      data: {
        invite_id: 101,
        club_id: 7,
        target_user_id: 'target-1',
        notification_id: 202,
      },
      error: null,
    }),
  } as any);

  const result = await repository.createClubInvite({
    actorUserId: 'captain-1',
    targetUserId: 'target-1',
  });

  assert.deepEqual(result, {
    inviteId: 101,
    clubId: 7,
    targetUserId: 'target-1',
    notificationId: 202,
  });
});

test('ClubWorkflowsRepository maps acceptClubInvite RPC payload', async () => {
  const repository = new ClubWorkflowsRepository({
    rpc: async () => ({
      data: {
        invite_id: 101,
        club_id: 7,
        membership_id: 303,
        player_id: 404,
        status: 'accepted',
      },
      error: null,
    }),
  } as any);

  const result = await repository.acceptClubInvite({
    actorUserId: 'target-1',
    inviteId: 101,
  });

  assert.deepEqual(result, {
    inviteId: 101,
    clubId: 7,
    membershipId: 303,
    playerId: 404,
    status: 'accepted',
  });
});
