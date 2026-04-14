import type { SupabaseClient } from '@supabase/supabase-js';

import type { RequestPrincipal, StreamMetadataDto } from '../domain/types';
import { ForbiddenError, ValidationError } from '../lib/errors';

const TWITCH_CLIENT_ID = 'kimne78kx3ncx6brgo4mv6wki5h1ko';

function isYouTubeHost(host: string): boolean {
  const normalizedHost = host.toLowerCase();
  return normalizedHost === 'youtube.com' ||
    normalizedHost === 'www.youtube.com' ||
    normalizedHost === 'm.youtube.com' ||
    normalizedHost === 'youtu.be';
}

function isTwitchHost(host: string): boolean {
  const normalizedHost = host.toLowerCase();
  return normalizedHost === 'twitch.tv' ||
    normalizedHost === 'www.twitch.tv' ||
    normalizedHost === 'm.twitch.tv';
}

function extractTwitchVideoId(url: URL): string | null {
  const segments = url.pathname.split('/').filter(Boolean);
  if (segments.length < 2 || segments[0] !== 'videos') {
    return null;
  }

  return segments[1]?.trim() || null;
}

function extractTwitchChannelLogin(url: URL): string | null {
  const segments = url.pathname.split('/').filter(Boolean);
  if (segments.length === 0) {
    return null;
  }

  const reservedSegments = new Set([
    'videos',
    'directory',
    'downloads',
    'jobs',
    'login',
    'logout',
    'search',
    'settings',
    'subscriptions',
    'wallet',
  ]);

  const candidate = segments[0]?.trim() ?? '';
  if (!candidate || reservedSegments.has(candidate.toLowerCase())) {
    return null;
  }

  return candidate;
}

function extractYouTubeVideoId(url: URL): string | null {
  const host = url.host.toLowerCase();

  if (host === 'youtu.be') {
    const shortId = url.pathname.split('/').filter(Boolean)[0]?.trim();
    return shortId || null;
  }

  const queryVideoId = url.searchParams.get('v')?.trim();
  if (queryVideoId) {
    return queryVideoId;
  }

  const segments = url.pathname.split('/').filter(Boolean);
  if (segments.length >= 2 && (segments[0] === 'shorts' || segments[0] === 'live')) {
    return segments[1]?.trim() || null;
  }

  return null;
}

function normalizeYouTubeWatchUrl(videoId: string): string {
  return `https://www.youtube.com/watch?v=${videoId}`;
}

function buildFallbackMetadata(parsedUrl: URL): StreamMetadataDto | null {
  const nowIso = new Date().toISOString();

  if (isYouTubeHost(parsedUrl.host)) {
    const videoId = extractYouTubeVideoId(parsedUrl);
    return {
      title: 'Video YouTube',
      normalizedUrl: videoId ? normalizeYouTubeWatchUrl(videoId) : parsedUrl.toString(),
      status: 'ended',
      provider: 'youtube',
      suggestedPlayedOn: nowIso,
      endedAt: null,
    };
  }

  if (isTwitchHost(parsedUrl.host)) {
    const videoId = extractTwitchVideoId(parsedUrl);
    if (videoId) {
      return {
        title: 'Video Twitch',
        normalizedUrl: `https://www.twitch.tv/videos/${videoId}`,
        status: 'ended',
        provider: 'twitch',
        suggestedPlayedOn: nowIso,
        endedAt: null,
      };
    }

    const channelLogin = extractTwitchChannelLogin(parsedUrl);
    if (channelLogin) {
      return {
        title: `${channelLogin} live su Twitch`,
        normalizedUrl: `https://www.twitch.tv/${channelLogin}`,
        status: 'live',
        provider: 'twitch',
        suggestedPlayedOn: nowIso,
        endedAt: null,
      };
    }

    return {
      title: 'Contenuto Twitch',
      normalizedUrl: parsedUrl.toString(),
      status: 'ended',
      provider: 'twitch',
      suggestedPlayedOn: nowIso,
      endedAt: null,
    };
  }

  return null;
}

function escapeGraphQl(value: string): string {
  return value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
}

function normalizeTwitchTitle(value: string | null | undefined): string | null {
  const trimmed = value?.trim();
  if (!trimmed) {
    return null;
  }

  return trimmed.replace(/\s+/g, ' ');
}

function normalizeComparisonKey(value: string | null | undefined): string | null {
  const trimmed = value?.trim().toLowerCase();
  if (!trimmed) {
    return null;
  }

  return trimmed.replace(/[^a-z0-9]+/g, '');
}

function removeTrailingOwnerSuffix(title: string, ownerValue: string | null | undefined): string {
  const normalizedOwner = normalizeComparisonKey(ownerValue);
  if (!normalizedOwner) {
    return title;
  }

  const parts = title.split(/\s*[-|]\s*/);
  if (parts.length < 2) {
    return title;
  }

  const lastSegment = parts[parts.length - 1];
  if (normalizeComparisonKey(lastSegment) !== normalizedOwner) {
    return title;
  }

  return parts.slice(0, -1).join(' - ');
}

function cleanTwitchTitle(
  value: string | null | undefined,
  options: {
    ownerDisplayName?: string | null;
    ownerLogin?: string | null;
  },
): string | null {
  const normalized = normalizeTwitchTitle(value);
  if (!normalized) {
    return null;
  }

  let cleaned = normalized;
  cleaned = removeTrailingOwnerSuffix(cleaned, options.ownerDisplayName);
  cleaned = removeTrailingOwnerSuffix(cleaned, options.ownerLogin);
  return cleaned.trim();
}

export class StreamMetadataService {
  constructor(
    private readonly db: SupabaseClient,
  ) {}

  async fetchMetadata(url: string, principal: RequestPrincipal): Promise<StreamMetadataDto> {
    if (!principal.canManageStreams) {
      throw new ForbiddenError('Non hai i permessi per recuperare i metadata delle live');
    }

    let parsedUrl: URL;
    try {
      parsedUrl = new URL(url);
    } catch (_) {
      throw new ValidationError('Inserisci un link live valido');
    }

    if (isTwitchHost(parsedUrl.host)) {
      try {
        const twitchMetadata = await this.fetchTwitchMetadata(parsedUrl);
        if (twitchMetadata) {
          return twitchMetadata;
        }
      } catch (_) {
        const fallback = buildFallbackMetadata(parsedUrl);
        if (fallback) {
          return fallback;
        }
      }
    }

    if (isYouTubeHost(parsedUrl.host)) {
      const youTubeMetadata = await this.fetchYouTubeMetadata(parsedUrl);
      if (youTubeMetadata) {
        return youTubeMetadata;
      }
    }

    try {
      const response = await this.db.functions.invoke('stream-metadata', {
        body: { url: parsedUrl.toString() },
      });

      if (response.error) {
        throw response.error;
      }

      const data = response.data;
      if (!data || typeof data !== 'object') {
        throw new ValidationError('Risposta metadata non valida');
      }

      const payload = data as Record<string, unknown>;
      if (payload.error != null) {
        throw new ValidationError(String(payload.error));
      }

      const title = String(payload.title ?? '').trim();
      const normalizedUrl = String(payload.normalizedUrl ?? parsedUrl.toString()).trim();
      const status = payload.status === 'live' ? 'live' : 'ended';
      const provider = String(payload.provider ?? 'generic').trim() || 'generic';
      const suggestedPlayedOn = String(payload.suggestedPlayedOn ?? '').trim();
      const endedAt = payload.endedAt == null ? null : String(payload.endedAt);

      if (!title || !suggestedPlayedOn) {
        throw new ValidationError('Metadata live incompleti');
      }

      return {
        title,
        normalizedUrl,
        status,
        provider,
        suggestedPlayedOn,
        endedAt,
      };
    } catch (_) {
      const fallback = buildFallbackMetadata(parsedUrl);
      if (fallback) {
        return fallback;
      }

      throw new ValidationError(
        'Non siamo riusciti a recuperare automaticamente i dati del link. Inserisci titolo e dettagli manualmente.',
      );
    }
  }

  private async fetchYouTubeMetadata(url: URL): Promise<StreamMetadataDto | null> {
    const videoId = extractYouTubeVideoId(url);
    if (!videoId) {
      return null;
    }

    const normalizedUrl = normalizeYouTubeWatchUrl(videoId);
    const nowIso = new Date().toISOString();

    try {
      const endpoint =
        `https://www.youtube.com/oembed?url=${encodeURIComponent(normalizedUrl)}&format=json`;
      const response = await fetch(endpoint);
      if (!response.ok) {
        return {
          title: 'Video YouTube',
          normalizedUrl,
          status: 'ended',
          provider: 'youtube',
          suggestedPlayedOn: nowIso,
          endedAt: null,
        };
      }

      const payload = await response.json() as Record<string, unknown>;
      const title = String(payload.title ?? '').trim() || 'Video YouTube';

      return {
        title,
        normalizedUrl,
        status: 'ended',
        provider: 'youtube',
        suggestedPlayedOn: nowIso,
        endedAt: null,
      };
    } catch (_) {
      return {
        title: 'Video YouTube',
        normalizedUrl,
        status: 'ended',
        provider: 'youtube',
        suggestedPlayedOn: nowIso,
        endedAt: null,
      };
    }
  }

  private async fetchTwitchMetadata(url: URL): Promise<StreamMetadataDto | null> {
    const videoId = extractTwitchVideoId(url);
    if (videoId) {
      return this.fetchTwitchVideoMetadata(videoId);
    }

    const channelLogin = extractTwitchChannelLogin(url);
    if (channelLogin) {
      return this.fetchTwitchChannelMetadata(channelLogin);
    }

    return null;
  }

  private async fetchTwitchVideoMetadata(videoId: string): Promise<StreamMetadataDto> {
    const payload = await this.postTwitchGraphQl(`
      query {
        video(id: "${escapeGraphQl(videoId)}") {
          id
          title
          publishedAt
          createdAt
          owner {
            displayName
            login
          }
        }
      }
    `);

    const data = payload.data;
    const video = typeof data === 'object' && data != null && 'video' in data
      ? (data as { video?: Record<string, unknown> | null }).video
      : null;

    if (!video) {
      throw new ValidationError('Impossibile leggere i dati del video Twitch');
    }

    const owner = typeof video.owner === 'object' && video.owner != null
      ? (video.owner as Record<string, unknown>)
      : null;
    const publishedAt = typeof video.publishedAt === 'string'
      ? video.publishedAt
      : typeof video.createdAt === 'string'
          ? video.createdAt
          : null;

    if (!publishedAt) {
      throw new ValidationError('Impossibile leggere la data del video Twitch');
    }

    const title = cleanTwitchTitle(
      typeof video.title === 'string' ? video.title : null,
      {
        ownerDisplayName: typeof owner?.displayName === 'string' ? owner.displayName : null,
        ownerLogin: typeof owner?.login === 'string' ? owner.login : null,
      },
    ) ??
        (typeof owner?.displayName === 'string' ? owner.displayName : 'Video Twitch');

    return {
      title,
      normalizedUrl: `https://www.twitch.tv/videos/${videoId}`,
      status: 'ended',
      provider: 'twitch',
      suggestedPlayedOn: new Date(publishedAt).toISOString(),
      endedAt: new Date(publishedAt).toISOString(),
    };
  }

  private async fetchTwitchChannelMetadata(channelLogin: string): Promise<StreamMetadataDto> {
    const payload = await this.postTwitchGraphQl(`
      query {
        user(login: "${escapeGraphQl(channelLogin)}") {
          id
          displayName
          login
          stream {
            id
            title
            createdAt
            type
          }
        }
      }
    `);

    const data = payload.data;
    const user = typeof data === 'object' && data != null && 'user' in data
      ? (data as { user?: Record<string, unknown> | null }).user
      : null;

    if (!user) {
      throw new ValidationError('Impossibile leggere i dati del canale Twitch');
    }

    const stream = typeof user.stream === 'object' && user.stream != null
      ? (user.stream as Record<string, unknown>)
      : null;

    if (!stream) {
      throw new ValidationError(
        'Il canale Twitch non risulta in diretta. Usa il link di una live attiva o di un video archiviato.',
      );
    }

    const createdAt = typeof stream.createdAt === 'string' ? stream.createdAt : null;
    if (!createdAt) {
      throw new ValidationError('Impossibile leggere la data della live Twitch');
    }

    const displayName = typeof user.displayName === 'string' && user.displayName.trim()
      ? user.displayName.trim()
      : channelLogin;
    const title = cleanTwitchTitle(
      typeof stream.title === 'string' ? stream.title : null,
      {
        ownerDisplayName: displayName,
        ownerLogin: typeof user.login === 'string' ? user.login : null,
      },
    ) ?? `${displayName} live su Twitch`;

    return {
      title,
      normalizedUrl: `https://www.twitch.tv/${channelLogin}`,
      status: 'live',
      provider: 'twitch',
      suggestedPlayedOn: new Date(createdAt).toISOString(),
      endedAt: null,
    };
  }

  private async postTwitchGraphQl(query: string): Promise<Record<string, unknown>> {
    const response = await fetch('https://gql.twitch.tv/gql', {
      method: 'POST',
      headers: {
        'Client-ID': TWITCH_CLIENT_ID,
        'Content-Type': 'text/plain;charset=UTF-8',
        Accept: '*/*',
      },
      body: JSON.stringify({ query }),
    });

    if (!response.ok) {
      throw new ValidationError('Twitch non ha risposto correttamente');
    }

    const decoded = await response.json();
    if (!decoded || typeof decoded !== 'object') {
      throw new ValidationError('Risposta Twitch non valida');
    }

    return decoded as Record<string, unknown>;
  }
}
