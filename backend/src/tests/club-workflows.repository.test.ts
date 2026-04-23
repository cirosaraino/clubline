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
