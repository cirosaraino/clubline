import assert from 'node:assert/strict';
import test from 'node:test';

import { env } from '../config/env';
import type { RequestPrincipal } from '../domain/types';
import { ServiceUnavailableError } from '../lib/errors';
import { ClubsService } from '../services/clubs.service';
import { FakeSupabaseClient } from './support/fake-supabase';

function buildPrincipal(userId: string): RequestPrincipal {
  return {
    authUser: {
      id: userId,
      email: `${userId}@example.com`,
      emailVerified: true,
      emailVerifiedAt: '2026-04-23T10:00:00.000Z',
    },
    club: null,
    membership: null,
    player: null,
    permissions: {
      club_id: 0,
      vice_manage_players: false,
      vice_manage_lineups: false,
      vice_manage_streams: false,
      vice_manage_attendance: false,
      vice_manage_team_info: false,
      updated_at: '2026-04-23T10:00:00.000Z',
    },
    isCaptain: false,
    isViceCaptain: false,
    hasClub: false,
    canManagePlayers: false,
    canManageLineups: false,
    canManageStreams: false,
    canManageAttendance: false,
    canManageTeamInfo: false,
  };
}

test('club workflows fail fast when hardened RPC path is unavailable and legacy fallback is disabled', async () => {
  const previousFallbackValue = env.ENABLE_LEGACY_WORKFLOW_FALLBACK;
  (env as { ENABLE_LEGACY_WORKFLOW_FALLBACK: boolean }).ENABLE_LEGACY_WORKFLOW_FALLBACK = false;

  try {
    const service = new ClubsService(new FakeSupabaseClient() as any);

    await assert.rejects(
      () =>
        service.createClub(
          {
            name: 'Clubline Hardening',
            owner_nome: 'Ciro',
            owner_cognome: 'Saraino',
            owner_id_console: 'ciro-hardening',
          },
          buildPrincipal('hardening-user'),
        ),
      (error: unknown) =>
        error instanceof ServiceUnavailableError &&
        error.code === 'hardened_workflow_unavailable' &&
        error.statusCode === 503,
    );
  } finally {
    (env as { ENABLE_LEGACY_WORKFLOW_FALLBACK: boolean }).ENABLE_LEGACY_WORKFLOW_FALLBACK =
      previousFallbackValue;
  }
});
