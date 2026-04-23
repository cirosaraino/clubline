import assert from 'node:assert/strict';
import test from 'node:test';

import type { AuthUserDto, MembershipRow, PlayerProfileRow } from '../domain/types';
import { AccessService } from '../services/access.service';
import { FakeSupabaseClient } from './support/fake-supabase';

function createMembership(
  overrides: Partial<MembershipRow> = {},
): MembershipRow {
  return {
    id: 10,
    club_id: 3,
    auth_user_id: 'auth-user-1',
    role: 'player',
    status: 'active',
    left_at: null,
    created_at: '2026-04-23T08:00:00.000Z',
    updated_at: '2026-04-23T08:00:00.000Z',
    ...overrides,
  };
}

function createPlayer(
  overrides: Partial<PlayerProfileRow> = {},
): PlayerProfileRow {
  return {
    id: 91,
    club_id: 3,
    membership_id: null,
    nome: 'Mario',
    cognome: 'Rossi',
    auth_user_id: null,
    account_email: 'mario@example.com',
    shirt_number: 10,
    primary_role: 'ATT',
    secondary_role: null,
    secondary_roles: [],
    id_console: 'mario-console',
    team_role: 'player',
    archived_at: null,
    created_at: '2026-04-23T08:00:00.000Z',
    updated_at: '2026-04-23T08:00:00.000Z',
    ...overrides,
  };
}

function authUser(overrides: Partial<AuthUserDto> = {}): AuthUserDto {
  return {
    id: 'auth-user-1',
    email: 'mario@example.com',
    emailVerified: true,
    emailVerifiedAt: '2026-04-23T07:50:00.000Z',
    ...overrides,
  };
}

test('resolvePrincipal re-links a club player by email when membership_id is missing', async () => {
  const membership = createMembership();
  const player = createPlayer();
  const db = new FakeSupabaseClient({
    memberships: [membership],
    clubs: [
      {
        id: 3,
        name: 'Napoli',
        normalized_name: 'napoli',
        slug: 'napoli',
        logo_url: null,
        logo_storage_path: null,
        primary_color: '#1D4ED8',
        accent_color: '#38BDF8',
        surface_color: '#112233',
        created_by_user_id: membership.auth_user_id,
      },
    ],
    player_profiles: [player],
    club_permission_settings: [],
  });

  const service = new AccessService(db as any);
  const principal = await service.resolvePrincipal(authUser());

  assert.equal(principal.player?.id, player.id);

  const updatedPlayer = db.findById<PlayerProfileRow>('player_profiles', player.id);
  assert.equal(updatedPlayer?.membership_id, membership.id);
  assert.equal(updatedPlayer?.auth_user_id, membership.auth_user_id);
});
