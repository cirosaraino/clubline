import type { SupabaseClient } from '@supabase/supabase-js';

import type {
  RequestPrincipal,
  StreamMetadataDto,
  StreamStatus,
} from '../domain/types';
import { ForbiddenError, ValidationError } from '../lib/errors';

const TWITCH_CLIENT_ID = 'kimne78kx3ncx6brgo4mv6wki5h1ko';

function isYouTubeHost(host: string): boolean {
  const normalizedHost = host.toLowerCase();
  return (
    normalizedHost === 'youtube.com' ||
    normalizedHost === 'www.youtube.com' ||
    normalizedHost === 'm.youtube.com' ||
    normalizedHost === 'youtu.be'
  );
}

function isTwitchHost(host: string): boolean {
  const normalizedHost = host.toLowerCase();
  return (
    normalizedHost === 'twitch.tv' ||
    normalizedHost === 'www.twitch.tv' ||
    normalizedHost === 'm.twitch.tv'
  );
}

function isTikTokHost(host: string): boolean {
  const normalizedHost = host.toLowerCase();
  return (
    normalizedHost === 'tiktok.com' ||
    normalizedHost === 'www.tiktok.com' ||
    normalizedHost === 'm.tiktok.com' ||
    normalizedHost === 'vm.tiktok.com' ||
    normalizedHost === 'vt.tiktok.com'
  );
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
  if (
    segments.length >= 2 &&
    (segments[0] === 'shorts' ||
      segments[0] === 'live' ||
      segments[0] === 'embed')
  ) {
    return segments[1]?.trim() || null;
  }

  return null;
}

function normalizeYouTubeWatchUrl(videoId: string): string {
  return `https://www.youtube.com/watch?v=${videoId}`;
}

function normalizeText(value: string | null | undefined): string | null {
  const trimmed = value?.trim();
  if (!trimmed) {
    return null;
  }

  return trimmed.replace(/\s+/g, ' ');
}

function normalizeDateTime(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }

  const trimmed = value.trim();
  if (!trimmed) {
    return null;
  }

  if (/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) {
    return `${trimmed}T00:00:00.000Z`;
  }

  const parsed = new Date(trimmed);
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }

  return parsed.toISOString();
}

function normalizeStreamStatus(
  value: unknown,
  fallback: StreamStatus = 'unknown',
): StreamStatus {
  const normalized = `${value ?? ''}`.trim().toLowerCase();
  switch (normalized) {
    case 'live':
      return 'live';
    case 'scheduled':
    case 'upcoming':
    case 'programmato':
      return 'scheduled';
    case 'ended':
    case 'completed':
    case 'conclusa':
      return 'ended';
    case 'unknown':
    case 'pending':
    case 'unverified':
    case 'offline':
    case 'not_live':
      return 'unknown';
    default:
      return fallback;
  }
}

function providerFromUrl(url: URL): string {
  if (isYouTubeHost(url.host)) {
    return 'youtube';
  }

  if (isTwitchHost(url.host)) {
    return 'twitch';
  }

  if (isTikTokHost(url.host)) {
    return 'tiktok';
  }

  const normalizedHost = url.host.toLowerCase().replace(/^www\./, '');
  return normalizedHost.split('.')[0] || 'web';
}

function normalizeProviderName(value: unknown, url: URL): string {
  const normalized = `${value ?? ''}`.trim().toLowerCase();
  if (!normalized) {
    return providerFromUrl(url);
  }

  if (['youtube', 'twitch', 'tiktok', 'web', 'generic'].includes(normalized)) {
    return normalized === 'generic' ? 'web' : normalized;
  }

  return normalized;
}

function safeNormalizedUrl(value: unknown, fallback: string): string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    return fallback;
  }

  return value.trim();
}

function defaultTitleForUrl(url: URL): string {
  if (isYouTubeHost(url.host)) {
    return 'Contenuto YouTube';
  }

  if (isTikTokHost(url.host)) {
    return 'Contenuto TikTok';
  }

  if (isTwitchHost(url.host)) {
    const videoId = extractTwitchVideoId(url);
    if (videoId) {
      return 'Video Twitch';
    }

    const channelLogin = extractTwitchChannelLogin(url);
    if (channelLogin) {
      return `${channelLogin} su Twitch`;
    }

    return 'Contenuto Twitch';
  }

  return 'Link live';
}

function buildFallbackMetadata(
  parsedUrl: URL,
  overrides: Partial<StreamMetadataDto> = {},
): StreamMetadataDto {
  const nowIso = new Date().toISOString();

  if (isYouTubeHost(parsedUrl.host)) {
    const videoId = extractYouTubeVideoId(parsedUrl);
    const status = normalizeStreamStatus(overrides.status, 'unknown');
    return {
      title: normalizeText(overrides.title) ?? 'Contenuto YouTube',
      normalizedUrl:
        safeNormalizedUrl(
          overrides.normalizedUrl,
          videoId ? normalizeYouTubeWatchUrl(videoId) : parsedUrl.toString(),
        ),
      status,
      provider: 'youtube',
      suggestedPlayedOn:
        normalizeDateTime(overrides.suggestedPlayedOn) ?? nowIso,
      endedAt: status === 'ended' ? normalizeDateTime(overrides.endedAt) : null,
    };
  }

  if (isTwitchHost(parsedUrl.host)) {
    const videoId = extractTwitchVideoId(parsedUrl);
    if (videoId) {
      const status = normalizeStreamStatus(overrides.status, 'ended');
      return {
        title: normalizeText(overrides.title) ?? 'Video Twitch',
        normalizedUrl: safeNormalizedUrl(
          overrides.normalizedUrl,
          `https://www.twitch.tv/videos/${videoId}`,
        ),
        status,
        provider: 'twitch',
        suggestedPlayedOn:
          normalizeDateTime(overrides.suggestedPlayedOn) ?? nowIso,
        endedAt:
          status === 'ended' ? normalizeDateTime(overrides.endedAt) : null,
      };
    }

    const channelLogin = extractTwitchChannelLogin(parsedUrl);
    const status = normalizeStreamStatus(overrides.status, 'unknown');
    return {
      title:
        normalizeText(overrides.title) ??
        (channelLogin == null ? 'Contenuto Twitch' : `${channelLogin} su Twitch`),
      normalizedUrl: safeNormalizedUrl(
        overrides.normalizedUrl,
        channelLogin == null
            ? parsedUrl.toString()
            : `https://www.twitch.tv/${channelLogin}`,
      ),
      status,
      provider: 'twitch',
      suggestedPlayedOn:
        normalizeDateTime(overrides.suggestedPlayedOn) ?? nowIso,
      endedAt: status === 'ended' ? normalizeDateTime(overrides.endedAt) : null,
    };
  }

  if (isTikTokHost(parsedUrl.host)) {
    const status = normalizeStreamStatus(overrides.status, 'unknown');
    return {
      title: normalizeText(overrides.title) ?? 'Contenuto TikTok',
      normalizedUrl: safeNormalizedUrl(
        overrides.normalizedUrl,
        parsedUrl.toString(),
      ),
      status,
      provider: 'tiktok',
      suggestedPlayedOn:
        normalizeDateTime(overrides.suggestedPlayedOn) ?? nowIso,
      endedAt: status === 'ended' ? normalizeDateTime(overrides.endedAt) : null,
    };
  }

  const status = normalizeStreamStatus(overrides.status, 'unknown');
  return {
    title: normalizeText(overrides.title) ?? defaultTitleForUrl(parsedUrl),
    normalizedUrl: safeNormalizedUrl(overrides.normalizedUrl, parsedUrl.toString()),
    status,
    provider: providerFromUrl(parsedUrl),
    suggestedPlayedOn: normalizeDateTime(overrides.suggestedPlayedOn) ?? nowIso,
    endedAt: status === 'ended' ? normalizeDateTime(overrides.endedAt) : null,
  };
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

function removeTrailingOwnerSuffix(
  title: string,
  ownerValue: string | null | undefined,
): string {
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
  constructor(private readonly db: SupabaseClient) {}

  async fetchMetadata(
    url: string,
    principal: RequestPrincipal,
  ): Promise<StreamMetadataDto> {
    if (!principal.canManageStreams) {
      throw new ForbiddenError(
        'Non hai i permessi per recuperare i metadata delle live',
      );
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
        if (twitchMetadata != null) {
          return twitchMetadata;
        }
      } catch (_) {
        // Fall back to the serverless metadata function or a safe local fallback.
      }
    }

    const functionMetadata = await this.tryFetchMetadataWithFunction(parsedUrl);
    if (functionMetadata != null) {
      return functionMetadata;
    }

    return buildFallbackMetadata(parsedUrl);
  }

  private async tryFetchMetadataWithFunction(
    parsedUrl: URL,
  ): Promise<StreamMetadataDto | null> {
    if (typeof this.db.functions?.invoke !== 'function') {
      return null;
    }

    try {
      const response = await this.db.functions.invoke('stream-metadata', {
        body: { url: parsedUrl.toString() },
      });

      if (response.error) {
        return null;
      }

      const data = response.data;
      if (!data || typeof data !== 'object') {
        return null;
      }

      const payload = data as Record<string, unknown>;
      if (payload.error != null) {
        return null;
      }

      const fallback = buildFallbackMetadata(parsedUrl);
      const status = normalizeStreamStatus(payload.status, fallback.status);
      return {
        title: normalizeText(`${payload.title ?? ''}`) ?? fallback.title,
        normalizedUrl: safeNormalizedUrl(
          payload.normalizedUrl,
          fallback.normalizedUrl,
        ),
        status,
        provider: normalizeProviderName(payload.provider, parsedUrl),
        suggestedPlayedOn:
          normalizeDateTime(payload.suggestedPlayedOn) ??
          fallback.suggestedPlayedOn,
        endedAt: status === 'ended' ? normalizeDateTime(payload.endedAt) : null,
      };
    } catch (_) {
      return null;
    }
  }

  private async fetchTwitchMetadata(
    url: URL,
  ): Promise<StreamMetadataDto | null> {
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

  private async fetchTwitchVideoMetadata(
    videoId: string,
  ): Promise<StreamMetadataDto> {
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
    const video =
      typeof data === 'object' && data != null && 'video' in data
          ? (data as { video?: Record<string, unknown> | null }).video
          : null;

    if (!video) {
      throw new ValidationError('Impossibile leggere i dati del video Twitch');
    }

    const owner =
      typeof video.owner === 'object' && video.owner != null
          ? (video.owner as Record<string, unknown>)
          : null;
    const publishedAt =
      typeof video.publishedAt === 'string'
          ? video.publishedAt
          : typeof video.createdAt === 'string'
            ? video.createdAt
            : null;

    const normalizedPublishedAt = normalizeDateTime(publishedAt);
    const title =
      cleanTwitchTitle(typeof video.title === 'string' ? video.title : null, {
        ownerDisplayName:
            typeof owner?.displayName === 'string' ? owner.displayName : null,
        ownerLogin: typeof owner?.login === 'string' ? owner.login : null,
      }) ??
      (typeof owner?.displayName === 'string'
          ? owner.displayName
          : 'Video Twitch');

    return {
      title,
      normalizedUrl: `https://www.twitch.tv/videos/${videoId}`,
      status: 'ended',
      provider: 'twitch',
      suggestedPlayedOn: normalizedPublishedAt ?? new Date().toISOString(),
      endedAt: normalizedPublishedAt,
    };
  }

  private async fetchTwitchChannelMetadata(
    channelLogin: string,
  ): Promise<StreamMetadataDto> {
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
    const user =
      typeof data === 'object' && data != null && 'user' in data
          ? (data as { user?: Record<string, unknown> | null }).user
          : null;

    if (!user) {
      throw new ValidationError('Impossibile leggere i dati del canale Twitch');
    }

    const normalizedUrl = new URL(`https://www.twitch.tv/${channelLogin}`);
    const stream =
      typeof user.stream === 'object' && user.stream != null
          ? (user.stream as Record<string, unknown>)
          : null;
    const displayName =
      typeof user.displayName === 'string' && user.displayName.trim()
          ? user.displayName.trim()
          : channelLogin;

    if (!stream) {
      return buildFallbackMetadata(normalizedUrl, {
        title: `${displayName} su Twitch`,
        provider: 'twitch',
        normalizedUrl: normalizedUrl.toString(),
        status: 'unknown',
      });
    }

    const createdAt =
      typeof stream.createdAt === 'string' ? stream.createdAt : null;
    const normalizedCreatedAt = normalizeDateTime(createdAt);
    const title =
      cleanTwitchTitle(typeof stream.title === 'string' ? stream.title : null, {
        ownerDisplayName: displayName,
        ownerLogin: typeof user.login === 'string' ? user.login : null,
      }) ??
      `${displayName} live su Twitch`;

    return {
      title,
      normalizedUrl: normalizedUrl.toString(),
      status: 'live',
      provider: 'twitch',
      suggestedPlayedOn: normalizedCreatedAt ?? new Date().toISOString(),
      endedAt: null,
    };
  }

  private async postTwitchGraphQl(
    query: string,
  ): Promise<Record<string, unknown>> {
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
