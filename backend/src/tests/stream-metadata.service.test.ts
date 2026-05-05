import assert from 'node:assert/strict';
import test from 'node:test';

import type { RequestPrincipal, VicePermissionsRow } from '../domain/types';
import { StreamMetadataService } from '../services/stream-metadata.service';

function createPermissions(overrides: Partial<VicePermissionsRow> = {}): VicePermissionsRow {
  return {
    club_id: 1,
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

function buildPrincipal(canManageStreams = true): RequestPrincipal {
  return {
    authUser: {
      id: 'captain-1',
      email: 'captain@example.com',
      emailVerified: true,
      emailVerifiedAt: '2026-04-20T09:00:00.000Z',
    },
    club: null,
    membership: null,
    player: null,
    permissions: createPermissions({ vice_manage_streams: canManageStreams }),
    isCaptain: canManageStreams,
    isViceCaptain: false,
    hasClub: true,
    canManagePlayers: false,
    canManageLineups: false,
    canManageStreams,
    canManageAttendance: false,
    canManageInvites: false,
    canManageClubInfo: false,
  };
}

function createDb(options?: {
  invokeResult?: { data: unknown; error: unknown };
}) {
  return {
    functions: {
      invoke: async () =>
        options?.invokeResult ?? {
          data: null,
          error: new Error('metadata unavailable'),
        },
    },
  };
}

function mockFetch(
  handler: (input: unknown, init?: unknown) => Promise<unknown> | unknown,
): () => void {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = (async (input: unknown, init?: unknown) =>
    handler(input, init)) as typeof fetch;
  return () => {
    globalThis.fetch = originalFetch;
  };
}

test('active YouTube live is not mapped to concluded when metadata says live', async () => {
  const service = new StreamMetadataService(
    createDb({
      invokeResult: {
        data: {
          title: 'Clubline vs Rivali',
          normalizedUrl: 'https://www.youtube.com/watch?v=yt-live-1',
          status: 'live',
          provider: 'youtube',
          suggestedPlayedOn: '2026-04-28T18:00:00.000Z',
          endedAt: null,
        },
        error: null,
      },
    }) as any,
  );

  const metadata = await service.fetchMetadata(
    'https://www.youtube.com/watch?v=yt-live-1',
    buildPrincipal(),
  );

  assert.equal(metadata.status, 'live');
  assert.equal(metadata.provider, 'youtube');
  assert.equal(metadata.normalizedUrl, 'https://www.youtube.com/watch?v=yt-live-1');
});

test('YouTube metadata failure maps safely to unknown instead of concluded', async () => {
  const service = new StreamMetadataService(createDb() as any);

  const metadata = await service.fetchMetadata(
    'https://www.youtube.com/watch?v=yt-live-2',
    buildPrincipal(),
  );

  assert.equal(metadata.status, 'unknown');
  assert.equal(metadata.provider, 'youtube');
  assert.equal(metadata.normalizedUrl, 'https://www.youtube.com/watch?v=yt-live-2');
  assert.equal(metadata.endedAt, null);
});

test('Twitch active channel maps to live when channel metadata confirms an active stream', async () => {
  const restoreFetch = mockFetch(async () => ({
    ok: true,
    json: async () => ({
      data: {
        user: {
          id: '1',
          displayName: 'ClublineTV',
          login: 'clublinetv',
          stream: {
            id: 'stream-1',
            title: 'Partita live - ClublineTV',
            createdAt: '2026-04-28T18:00:00.000Z',
            type: 'live',
          },
        },
      },
    }),
  }));

  try {
    const service = new StreamMetadataService(createDb() as any);
    const metadata = await service.fetchMetadata(
      'https://www.twitch.tv/clublinetv',
      buildPrincipal(),
    );

    assert.equal(metadata.status, 'live');
    assert.equal(metadata.provider, 'twitch');
    assert.equal(metadata.normalizedUrl, 'https://www.twitch.tv/clublinetv');
    assert.equal(metadata.title, 'Partita live');
  } finally {
    restoreFetch();
  }
});

test('Twitch offline channel maps to unknown instead of concluded', async () => {
  const restoreFetch = mockFetch(async () => ({
    ok: true,
    json: async () => ({
      data: {
        user: {
          id: '1',
          displayName: 'ClublineTV',
          login: 'clublinetv',
          stream: null,
        },
      },
    }),
  }));

  try {
    const service = new StreamMetadataService(createDb() as any);
    const metadata = await service.fetchMetadata(
      'https://www.twitch.tv/clublinetv',
      buildPrincipal(),
    );

    assert.equal(metadata.status, 'unknown');
    assert.equal(metadata.provider, 'twitch');
    assert.equal(metadata.endedAt, null);
  } finally {
    restoreFetch();
  }
});

test('TikTok unreliable metadata maps safely to unknown', async () => {
  const service = new StreamMetadataService(createDb() as any);

  const metadata = await service.fetchMetadata(
    'https://www.tiktok.com/@clubline/live',
    buildPrincipal(),
  );

  assert.equal(metadata.status, 'unknown');
  assert.equal(metadata.provider, 'tiktok');
  assert.equal(metadata.endedAt, null);
});

test('unsupported URLs still return safe fallback metadata', async () => {
  const service = new StreamMetadataService(createDb() as any);

  const metadata = await service.fetchMetadata(
    'https://example.com/live/clubline',
    buildPrincipal(),
  );

  assert.equal(metadata.status, 'unknown');
  assert.equal(metadata.provider, 'example');
  assert.equal(metadata.normalizedUrl, 'https://example.com/live/clubline');
  assert.equal(metadata.endedAt, null);
});
