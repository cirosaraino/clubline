import assert from 'node:assert/strict';
import test from 'node:test';

import type {
  ClubInfoRow,
  ClubRow,
  MembershipRow,
  RequestPrincipal,
  VicePermissionsRow,
} from '../domain/types';
import { ClubInfoService } from '../services/club-info.service';
import { FakeSupabaseClient } from './support/fake-supabase';

const ONE_PIXEL_PNG_DATA_URL =
  'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a6GQAAAAASUVORK5CYII=';

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
    id: 10,
    club_id: 1,
    auth_user_id: 'captain-1',
    role: 'captain',
    status: 'active',
    left_at: null,
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
    vice_manage_invites: false,
    vice_manage_team_info: false,
    updated_at: '2026-04-20T10:00:00.000Z',
    ...overrides,
  };
}

function buildPrincipal(club: ClubRow, membership: MembershipRow): RequestPrincipal {
  return {
    authUser: {
      id: membership.auth_user_id,
      email: 'captain@example.com',
      emailVerified: true,
      emailVerifiedAt: '2026-04-20T09:00:00.000Z',
    },
    club,
    membership,
    player: null,
    permissions: createPermissions(club.id, { vice_manage_team_info: true }),
    isCaptain: membership.role === 'captain',
    isViceCaptain: membership.role === 'vice_captain',
    hasClub: true,
    canManagePlayers: true,
    canManageLineups: true,
    canManageStreams: true,
    canManageAttendance: true,
    canManageInvites: false,
    canManageClubInfo: true,
  };
}

function createClubInfoInput(
  overrides: Partial<ClubInfoRow> & { logo_data_url?: string | null } = {},
): ClubInfoRow & { logo_data_url?: string | null } {
  return {
    id: 1,
    club_name: 'Club Uno',
    crest_url: null,
    crest_storage_path: null,
    website_url: null,
    youtube_url: null,
    discord_url: null,
    facebook_url: null,
    instagram_url: null,
    twitch_url: null,
    tiktok_url: null,
    additional_links: [],
    primary_color: null,
    accent_color: null,
    surface_color: null,
    slug: null,
    updated_at: null,
    logo_data_url: null,
    ...overrides,
  };
}

test('updateClubInfo keeps the current storage-backed logo when no new logo is provided', async () => {
  const club = createClub({
    logo_url: 'https://storage.example.test/clubs/1/logo-old.png',
    logo_storage_path: 'clubs/1/logo-old.png',
    primary_color: '#123456',
    accent_color: '#ABCDEF',
    surface_color: '#111827',
  });
  const membership = createMembership();
  const db = new FakeSupabaseClient({
    clubs: [club],
    club_settings: [{ club_id: 1, website_url: null, additional_links: [] }],
  });
  const service = new ClubInfoService(db as any);

  const result = await service.updateClubInfo(
    createClubInfoInput({
      club_name: 'Club Uno Reloaded',
      website_url: 'https://club.example.com',
    }),
    buildPrincipal(club, membership),
  );

  assert.equal(result.club_name, 'Club Uno Reloaded');
  assert.equal(result.crest_url, 'https://storage.example.test/clubs/1/logo-old.png');
  assert.equal(result.crest_storage_path, 'clubs/1/logo-old.png');
  assert.equal(result.primary_color, '#123456');
  assert.equal(result.accent_color, '#ABCDEF');
  assert.equal(result.surface_color, '#111827');
  assert.deepEqual(db.uploadedStoragePaths, []);
  assert.deepEqual(db.removedStoragePaths, []);

  const savedClub = db.rows<ClubRow>('clubs')[0];
  assert.equal(savedClub?.logo_url, 'https://storage.example.test/clubs/1/logo-old.png');
  assert.equal(savedClub?.logo_storage_path, 'clubs/1/logo-old.png');
});

test('updateClubInfo with logo upload stores a stable storage path and keeps palette values', async () => {
  const club = createClub();
  const membership = createMembership();
  const db = new FakeSupabaseClient({
    clubs: [club],
    club_settings: [{ club_id: 1, website_url: null, additional_links: [] }],
  });
  const service = new ClubInfoService(db as any);

  const result = await service.updateClubInfo(
    createClubInfoInput({
      logo_data_url: ONE_PIXEL_PNG_DATA_URL,
      primary_color: '#1274FF',
      accent_color: '#00D4C6',
      surface_color: '#12384E',
    }),
    buildPrincipal(club, membership),
  );

  assert.match(result.crest_storage_path ?? '', /^clubs\/1\/logo-/);
  assert.equal(
    result.crest_url?.startsWith('https://storage.example.test/clubs/1/logo-'),
    true,
  );
  assert.equal(result.primary_color, '#1274FF');
  assert.equal(result.accent_color, '#00D4C6');
  assert.equal(result.surface_color, '#12384E');
  assert.deepEqual(db.uploadedStoragePaths, [result.crest_storage_path]);

  const savedClub = db.rows<ClubRow>('clubs')[0];
  assert.equal(savedClub?.logo_storage_path, result.crest_storage_path);
  assert.equal(savedClub?.primary_color, '#1274FF');
  assert.equal(savedClub?.accent_color, '#00D4C6');
  assert.equal(savedClub?.surface_color, '#12384E');
});

test('updateClubInfo switching to an external logo clears old storage references and uses safe fallback colors', async () => {
  const club = createClub({
    logo_url: 'https://storage.example.test/clubs/1/logo-old.png',
    logo_storage_path: 'clubs/1/logo-old.png',
    primary_color: '#AA2200',
    accent_color: '#00BBCC',
    surface_color: '#101820',
  });
  const membership = createMembership();
  const db = new FakeSupabaseClient({
    clubs: [club],
    club_settings: [{ club_id: 1, website_url: null, additional_links: [] }],
  });
  const service = new ClubInfoService(db as any);

  const result = await service.updateClubInfo(
    createClubInfoInput({
      crest_url: 'https://cdn.example.com/new-crest.png',
    }),
    buildPrincipal(club, membership),
  );

  assert.equal(result.crest_url, 'https://cdn.example.com/new-crest.png');
  assert.equal(result.crest_storage_path, null);
  assert.equal(result.primary_color, '#1F2937');
  assert.equal(result.accent_color, '#0F766E');
  assert.equal(result.surface_color, '#0F172A');
  assert.deepEqual(db.removedStoragePaths, ['clubs/1/logo-old.png']);

  const savedClub = db.rows<ClubRow>('clubs')[0];
  assert.equal(savedClub?.logo_url, 'https://cdn.example.com/new-crest.png');
  assert.equal(savedClub?.logo_storage_path, null);
});
