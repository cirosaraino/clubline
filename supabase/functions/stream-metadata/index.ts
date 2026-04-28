const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

type StreamMetadata = {
  title: string;
  normalizedUrl: string;
  status: 'live' | 'scheduled' | 'ended' | 'unknown';
  provider: string;
  suggestedPlayedOn: string;
  endedAt: string | null;
  debug?: Record<string, unknown>;
};

const twitchClientId = 'kimne78kx3ncx6brgo4mv6wki5h1ko';

function isNonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.trim() !== '';
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}

function normalizeUrl(value: string): URL {
  const trimmed = value.trim();
  if (!trimmed) {
    throw new Error('Link obbligatorio');
  }

  const url = new URL(trimmed);
  if (url.protocol !== 'http:' && url.protocol !== 'https:') {
    throw new Error('Il link deve iniziare con http o https');
  }

  return url;
}

function extractYouTubeVideoId(url: URL): string | null {
  const host = url.hostname.replace(/^www\./, '');

  if (host === 'youtu.be') {
    return url.pathname.split('/').filter(Boolean)[0] ?? null;
  }

  if (host === 'youtube.com' || host === 'm.youtube.com') {
    if (url.pathname === '/watch') {
      return url.searchParams.get('v');
    }

    const segments = url.pathname.split('/').filter(Boolean);
    if (segments.length >= 2 && ['live', 'shorts', 'embed'].includes(segments[0])) {
      return segments[1];
    }
  }

  return null;
}

function isTwitchHost(hostname: string): boolean {
  const host = hostname.replace(/^www\./, '');
  return host === 'twitch.tv' || host === 'm.twitch.tv';
}

function isTikTokHost(hostname: string): boolean {
  const host = hostname.replace(/^www\./, '');
  return (
    host === 'tiktok.com' ||
    host === 'm.tiktok.com' ||
    host === 'vm.tiktok.com' ||
    host === 'vt.tiktok.com'
  );
}

function extractTwitchVideoId(url: URL): string | null {
  if (!isTwitchHost(url.hostname)) {
    return null;
  }

  const segments = url.pathname.split('/').filter(Boolean);
  if (segments.length >= 2 && segments[0] === 'videos') {
    return segments[1]?.replace(/^v/i, '') ?? null;
  }

  return null;
}

function extractTwitchChannelLogin(url: URL): string | null {
  if (!isTwitchHost(url.hostname)) {
    return null;
  }

  const segments = url.pathname.split('/').filter(Boolean);
  if (segments.length !== 1) {
    return null;
  }

  const candidate = segments[0]?.toLowerCase();
  if (!isNonEmptyString(candidate)) {
    return null;
  }

  const reservedSegments = new Set([
    'directory',
    'downloads',
    'jobs',
    'login',
    'messages',
    'p',
    'search',
    'settings',
    'signup',
    'subscriptions',
    'turbo',
    'videos',
  ]);

  return reservedSegments.has(candidate) ? null : candidate;
}

function graphqlString(value: string): string {
  return JSON.stringify(value);
}

function extractTagAttributeValue(tagHtml: string, attribute: string): string | null {
  const pattern = new RegExp(`${attribute}\\s*=\\s*(['"])(.*?)\\1`, 'i');
  const match = tagHtml.match(pattern);
  return match?.[2] ?? null;
}

function extractTagContent(
  html: string,
  tag: string,
  attribute: string,
  value: string,
  resultAttribute = 'content',
): string | null {
  const tags = html.match(new RegExp(`<${tag}\\b[^>]*>`, 'gi')) ?? [];

  for (const tagHtml of tags) {
    const attributeValue = extractTagAttributeValue(tagHtml, attribute);
    if (attributeValue?.toLowerCase() !== value.toLowerCase()) {
      continue;
    }

    const result = extractTagAttributeValue(tagHtml, resultAttribute);
    if (isNonEmptyString(result)) {
      return result.trim();
    }
  }

  return null;
}

function extractMetaContent(html: string, attribute: string, value: string): string | null {
  return extractTagContent(html, 'meta', attribute, value);
}

function extractAttributeContent(
  html: string,
  tag: string,
  attribute: string,
  value: string,
  resultAttribute = 'content',
): string | null {
  return extractTagContent(html, tag, attribute, value, resultAttribute);
}

function extractTitleTag(html: string): string | null {
  const match = html.match(/<title>([^<]+)<\/title>/i);
  return match?.[1]?.trim() ?? null;
}

function cleanStreamTitle(value: string | null | undefined): string | null {
  if (!isNonEmptyString(value)) return null;

  return value
    .trim()
    .replace(/\s*[-|]\s*(YouTube|Twitch|Kick|Facebook)\s*$/i, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function normalizeComparisonKey(value: string | null | undefined): string | null {
  if (!isNonEmptyString(value)) return null;

  const normalized = value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '');

  return normalized.length == 0 ? null : normalized;
}

function removeTrailingOwnerSuffix(title: string, ownerValue: string | null | undefined): string {
  const normalizedOwner = normalizeComparisonKey(ownerValue);
  if (normalizedOwner == null) return title;

  const parts = title.split(/\s*[-|]\s*/);
  if (parts.length < 2) return title;

  const lastSegment = parts[parts.length - 1] ?? '';
  if (normalizeComparisonKey(lastSegment) !== normalizedOwner) {
    return title;
  }

  return parts.slice(0, -1).join(' - ').trim();
}

function cleanTwitchTitle(
  value: string | null | undefined,
  ownerDisplayName?: string | null,
  ownerLogin?: string | null,
): string | null {
  const normalized = cleanStreamTitle(value);
  if (normalized == null) return null;

  const withoutDisplayName = removeTrailingOwnerSuffix(normalized, ownerDisplayName);
  return removeTrailingOwnerSuffix(withoutDisplayName, ownerLogin);
}

function collectJsonLdObjects(value: unknown, objects: Record<string, unknown>[]) {
  if (Array.isArray(value)) {
    for (const item of value) {
      collectJsonLdObjects(item, objects);
    }
    return;
  }

  if (value == null || typeof value !== 'object') return;

  const record = value as Record<string, unknown>;
  objects.push(record);

  for (const nestedValue of Object.values(record)) {
    collectJsonLdObjects(nestedValue, objects);
  }
}

function extractJsonLdObjects(html: string): Record<string, unknown>[] {
  const matches = html.matchAll(
    /<script[^>]+type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi,
  );
  const objects: Record<string, unknown>[] = [];

  for (const match of matches) {
    const rawJson = match[1]?.trim();
    if (!isNonEmptyString(rawJson)) continue;

    try {
      const parsed = JSON.parse(rawJson);
      collectJsonLdObjects(parsed, objects);
    } catch {
      // Ignore malformed JSON-LD blocks.
    }
  }

  return objects;
}

function jsonLdHasType(record: Record<string, unknown>, expectedType: string): boolean {
  const type = record['@type'];

  if (typeof type === 'string') {
    return type.toLowerCase() === expectedType.toLowerCase();
  }

  if (Array.isArray(type)) {
    return type.some(
      (item) => typeof item === 'string' && item.toLowerCase() === expectedType.toLowerCase(),
    );
  }

  return false;
}

function findJsonLdObject(
  objects: Record<string, unknown>[],
  expectedType: string,
): Record<string, unknown> | null {
  for (const object of objects) {
    if (jsonLdHasType(object, expectedType)) {
      return object;
    }
  }

  return null;
}

function readJsonLdString(
  object: Record<string, unknown> | null,
  ...keys: string[]
): string | null {
  if (object == null) return null;

  for (const key of keys) {
    const value = object[key];
    if (isNonEmptyString(value)) {
      return value.trim();
    }
  }

  return null;
}

function extractJsonStringValue(html: string, key: string): string | null {
  const pattern = new RegExp(`"${key}":"([^"]+)"`, 'i');
  const match = html.match(pattern);
  return match?.[1]?.trim() ?? null;
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function extractYouTubePublishedTextFromSearchHtml(
  html: string,
  videoId: string,
): string | null {
  const pattern = new RegExp(
    `"videoId":"${escapeRegExp(videoId)}"[\\s\\S]{0,2000}?"publishedTimeText":\\{"simpleText":"([^"]+)"`,
    'i',
  );
  const match = html.match(pattern);
  return match?.[1]?.trim() ?? null;
}

function dateToIsoDate(value: Date): string {
  if (Number.isNaN(value.getTime())) return todayIsoDate();
  return value.toISOString().split('T')[0];
}

function shiftDate(date: Date, amount: number, unit: string): Date {
  const next = new Date(date);

  switch (unit) {
    case 'minute':
      next.setUTCMinutes(next.getUTCMinutes() - amount);
      break;
    case 'hour':
      next.setUTCHours(next.getUTCHours() - amount);
      break;
    case 'day':
      next.setUTCDate(next.getUTCDate() - amount);
      break;
    case 'week':
      next.setUTCDate(next.getUTCDate() - amount * 7);
      break;
    case 'month':
      next.setUTCMonth(next.getUTCMonth() - amount);
      break;
    case 'year':
      next.setUTCFullYear(next.getUTCFullYear() - amount);
      break;
  }

  return next;
}

function parseRelativePublishedDate(text: string | null | undefined): string | null {
  if (!isNonEmptyString(text)) return null;

  const normalized = text
    .toLowerCase()
    .replace(/trasmesso in streaming\s*/g, '')
    .replace(/streamed\s*/g, '')
    .replace(/\s+/g, ' ')
    .trim();

  if (normalized.includes('oggi') || normalized.includes('today') || normalized.includes('adesso')) {
    return todayIsoDate();
  }

  if (normalized.includes('ieri') || normalized.includes('yesterday')) {
    return dateToIsoDate(shiftDate(new Date(), 1, 'day'));
  }

  const match = normalized.match(/(\d+)\s+(minuto|minuti|minute|minutes|ora|ore|hour|hours|giorno|giorni|day|days|settimana|settimane|week|weeks|mese|mesi|month|months|anno|anni|year|years)/i);
  if (match == null) {
    return null;
  }

  const amount = Number.parseInt(match[1], 10);
  if (Number.isNaN(amount) || amount <= 0) {
    return null;
  }

  const rawUnit = match[2].toLowerCase();
  const unit =
    rawUnit.startsWith('minut') || rawUnit.startsWith('minute')
        ? 'minute'
        : rawUnit === 'ora' || rawUnit === 'ore' || rawUnit.startsWith('hour')
            ? 'hour'
            : rawUnit.startsWith('giorn') || rawUnit.startsWith('day')
                ? 'day'
                : rawUnit.startsWith('settiman') || rawUnit.startsWith('week')
                    ? 'week'
                    : rawUnit.startsWith('mes') || rawUnit.startsWith('month')
                        ? 'month'
                        : 'year';

  return dateToIsoDate(shiftDate(new Date(), amount, unit));
}

function extractJsonObjectFromAssignment(html: string, variableName: string): string | null {
  const assignment = new RegExp(`${variableName}\\s*=\\s*`, 'm');
  const match = assignment.exec(html);
  if (!match || match.index === undefined) return null;

  const start = match.index + match[0].length;
  let depth = 0;
  let inString = false;
  let escaped = false;

  for (let index = start; index < html.length; index++) {
    const char = html[index];

    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char === '\\') {
        escaped = true;
      } else if (char === '"') {
        inString = false;
      }
      continue;
    }

    if (char === '"') {
      inString = true;
      continue;
    }

    if (char === '{') {
      depth += 1;
      continue;
    }

    if (char === '}') {
      depth -= 1;
      if (depth === 0) {
        return html.slice(start, index + 1);
      }
    }
  }

  return null;
}

async function fetchHtml(url: string): Promise<string> {
  const requestUrl = new URL(url);
  const response = await fetch(url, {
    headers: {
      'User-Agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
      'Accept-Language': 'it-IT,it;q=0.9,en;q=0.8',
      ...(requestUrl.hostname.includes('youtube.com') || requestUrl.hostname.includes('youtu.be')
          ? {
              Cookie: 'CONSENT=YES+cb.20210328-17-p0.en+FX+667; PREF=hl=it&tz=Europe.Rome',
            }
          : {}),
    },
  });

  if (!response.ok) {
    throw new Error('Impossibile leggere il link della live');
  }

  return await response.text();
}

async function fetchJson(url: string): Promise<Record<string, unknown> | null> {
  const requestUrl = new URL(url);
  const response = await fetch(url, {
    headers: {
      'User-Agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
      'Accept-Language': 'it-IT,it;q=0.9,en;q=0.8',
      ...(requestUrl.hostname.includes('youtube.com') || requestUrl.hostname.includes('youtu.be')
          ? {
              Cookie: 'CONSENT=YES+cb.20210328-17-p0.en+FX+667; PREF=hl=it&tz=Europe.Rome',
            }
          : {}),
    },
  });

  if (!response.ok) {
    return null;
  }

  const data = await response.json();
  return data && typeof data === 'object' ? (data as Record<string, unknown>) : null;
}

async function postJson(
  url: string,
  body: unknown,
  headers: Record<string, string> = {},
): Promise<Record<string, unknown> | null> {
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'User-Agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
      'Accept-Language': 'it-IT,it;q=0.9,en;q=0.8',
      'Content-Type': 'text/plain;charset=UTF-8',
      ...headers,
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    return null;
  }

  const data = await response.json();
  return data && typeof data === 'object' ? (data as Record<string, unknown>) : null;
}

async function fetchYouTubePlayerResponse(
  videoId: string,
): Promise<Record<string, unknown> | null> {
  const response = await fetch(
    `https://www.youtube.com/watch?v=${videoId}&pbj=1&hl=it&bpctr=9999999999&has_verified=1`,
    {
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
        'Accept-Language': 'it-IT,it;q=0.9,en;q=0.8',
        'Cookie': 'CONSENT=YES+cb.20210328-17-p0.en+FX+667; PREF=hl=it&tz=Europe.Rome',
        'Referer': 'https://www.youtube.com/',
        'X-YouTube-Client-Name': '1',
        'X-YouTube-Client-Version': '2.20260408.02.00',
      },
    },
  );

  if (!response.ok) {
    return null;
  }

  const data = await response.json();
  if (data == null || typeof data !== 'object') {
    return null;
  }

  const record = data as Record<string, unknown>;
  const playerResponse = record['playerResponse'];

  return playerResponse != null && typeof playerResponse === 'object'
      ? (playerResponse as Record<string, unknown>)
      : null;
}

function isoDatePart(value: string | null | undefined): string | null {
  if (!isNonEmptyString(value)) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return date.toISOString().split('T')[0];
}

function normalizeDateValue(value: string | null | undefined): string | null {
  if (!isNonEmptyString(value)) return null;

  const trimmed = value.trim();
  if (/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) {
    return `${trimmed}T00:00:00Z`;
  }

  return trimmed;
}

function todayIsoDate(): string {
  return new Date().toISOString().split('T')[0];
}

async function fetchYouTubeMetadata(
  url: URL,
  videoId: string,
  debug = false,
): Promise<StreamMetadata> {
  const canonicalWatchUrl = `https://www.youtube.com/watch?v=${videoId}`;
  const watchUrl = `${canonicalWatchUrl}&hl=it&bpctr=9999999999&has_verified=1`;
  const pbjPlayerResponse = await fetchYouTubePlayerResponse(videoId);
  const html = await fetchHtml(watchUrl);
  const jsonLdObjects: Record<string, unknown>[] = extractJsonLdObjects(html);
  const playerJson = extractJsonObjectFromAssignment(html, 'ytInitialPlayerResponse');
  const oEmbed = await fetchJson(
    `https://www.youtube.com/oembed?url=${encodeURIComponent(canonicalWatchUrl)}&format=json`,
  );
  const videoJsonLd = findJsonLdObject(jsonLdObjects, 'VideoObject');
  const broadcastJsonLd = findJsonLdObject(jsonLdObjects, 'BroadcastEvent');

  if (pbjPlayerResponse == null && !playerJson) {
    throw new Error('Impossibile leggere i dati della live YouTube');
  }

  const parsed = pbjPlayerResponse ?? JSON.parse(playerJson!);
  const videoDetails = parsed.videoDetails ?? {};
  const playerMicroformat = parsed.microformat?.playerMicroformatRenderer ?? {};
  const liveDetails = playerMicroformat.liveBroadcastDetails ?? {};
  const metaPublishedAt =
    readJsonLdString(videoJsonLd, 'endDate', 'startDate', 'uploadDate', 'datePublished') ??
    readJsonLdString(broadcastJsonLd, 'endDate', 'startDate') ??
    (html == null ? null : extractAttributeContent(html, 'meta', 'itemprop', 'datePublished')) ??
    (html == null ? null : extractAttributeContent(html, 'meta', 'itemprop', 'uploadDate')) ??
    (html == null ? null : extractMetaContent(html, 'property', 'article:published_time')) ??
    (html == null ? null : extractMetaContent(html, 'name', 'datePublished')) ??
    (html == null ? null : extractMetaContent(html, 'name', 'uploadDate'));
  const rawPublishedAt =
    html == null
        ? null
        : extractJsonStringValue(html, 'publishDate') ?? extractJsonStringValue(html, 'uploadDate');

  const startedAt =
    isNonEmptyString(liveDetails.startTimestamp) ? liveDetails.startTimestamp : null;
  const publishedAt =
    normalizeDateValue(playerMicroformat.publishDate) ??
    normalizeDateValue(playerMicroformat.uploadDate) ??
    normalizeDateValue(metaPublishedAt) ??
    normalizeDateValue(rawPublishedAt);
  let publishedTextFromSearch: string | null = null;
  let fallbackPublishedOn: string | null = null;

  if (publishedAt == null && fallbackPublishedOn == null) {
    try {
      const searchHtml = await fetchHtml(
        `https://www.youtube.com/results?search_query=${encodeURIComponent(videoId)}&hl=it`,
      );
      publishedTextFromSearch = extractYouTubePublishedTextFromSearchHtml(searchHtml, videoId);
      fallbackPublishedOn = parseRelativePublishedDate(publishedTextFromSearch);
    } catch {
      publishedTextFromSearch = null;
      fallbackPublishedOn = null;
    }
  }

  const title =
    cleanStreamTitle(isNonEmptyString(oEmbed?.title) ? oEmbed.title : null) ??
    cleanStreamTitle(isNonEmptyString(videoDetails.title) ? videoDetails.title : null) ??
    cleanStreamTitle(readJsonLdString(videoJsonLd, 'name', 'headline')) ??
    cleanStreamTitle(html == null ? null : extractMetaContent(html, 'property', 'og:title')) ??
    cleanStreamTitle(html == null ? null : extractTitleTag(html)) ??
    'Live YouTube';

  const isLiveNow =
    liveDetails.isLiveNow === true ||
    videoDetails.isLive === true;
  const isLiveContent = videoDetails.isLiveContent === true;
  const endedAt =
    typeof liveDetails.endTimestamp === 'string' && liveDetails.endTimestamp.trim() !== ''
      ? liveDetails.endTimestamp
      : null;
  const startedAtValue = normalizeDateValue(startedAt);
  const hasScheduledStart =
    startedAtValue != null &&
    endedAt == null &&
    new Date(startedAtValue).getTime() > Date.now() + 60 * 1000;
  const isScheduled =
    hasScheduledStart ||
    playerMicroformat.isUpcoming === true ||
    liveDetails.isUpcoming === true ||
    videoDetails.isUpcoming === true;
  const status: StreamMetadata['status'] = isLiveNow
    ? 'live'
    : endedAt != null
      ? 'ended'
      : isScheduled
        ? 'scheduled'
        : isLiveContent || startedAt != null
          ? 'unknown'
          : 'ended';

  const suggestedPlayedOn =
    isoDatePart(endedAt) ??
    isoDatePart(startedAt) ??
    isoDatePart(publishedAt) ??
    fallbackPublishedOn ??
    todayIsoDate();

  return {
    title,
    normalizedUrl: canonicalWatchUrl,
    status,
    provider: 'youtube',
    suggestedPlayedOn,
    endedAt: status === 'ended' ? endedAt : null,
    ...(debug
        ? {
            debug: {
              watchUrl,
              usedPbj: pbjPlayerResponse != null,
              pbjKeys: pbjPlayerResponse == null ? [] : Object.keys(pbjPlayerResponse),
              hasPlayerJson: playerJson != null,
              htmlTitle: html == null ? null : extractTitleTag(html),
              metaPublishedAt,
              rawPublishedAt,
              publishedTextFromSearch,
              fallbackPublishedOn,
              status,
              startedAt,
              endedAt,
              publishDate: playerMicroformat.publishDate ?? null,
              uploadDate: playerMicroformat.uploadDate ?? null,
              htmlHasDatePublished: html?.includes('datePublished') ?? false,
              htmlHasUploadDate: html?.includes('uploadDate') ?? false,
              htmlHasConsent: html == null
                  ? false
                  : html.toLowerCase().includes('before you continue') ||
                        html.toLowerCase().includes('prima di continuare'),
              htmlPreview: html?.slice(0, 500) ?? null,
            },
          }
        : {}),
  };
}

async function fetchTwitchVideoMetadata(
  url: URL,
  videoId: string,
  debug = false,
): Promise<StreamMetadata> {
  const response = await postJson(
    'https://gql.twitch.tv/gql',
    {
      query: `
        query {
          video(id: ${graphqlString(videoId)}) {
            id
            title
            publishedAt
            createdAt
            broadcastType
            owner {
              displayName
              login
            }
          }
        }
      `,
    },
    {
      'Client-ID': twitchClientId,
      Accept: '*/*',
    },
  );

  const data = response?.['data'];
  const video = data && typeof data === 'object'
    ? (data as Record<string, unknown>)['video']
    : null;

  if (video == null || typeof video !== 'object') {
    throw new Error('Impossibile leggere i dati del video Twitch');
  }

  const videoRecord = video as Record<string, unknown>;
  const ownerRecord =
    videoRecord['owner'] != null && typeof videoRecord['owner'] === 'object'
      ? (videoRecord['owner'] as Record<string, unknown>)
      : null;
  const publishedAt = isNonEmptyString(videoRecord['publishedAt'])
    ? videoRecord['publishedAt']
    : isNonEmptyString(videoRecord['createdAt'])
        ? videoRecord['createdAt']
        : null;
  const title =
    cleanTwitchTitle(
      videoRecord['title']?.toString(),
      ownerRecord?.['displayName']?.toString(),
      ownerRecord?.['login']?.toString(),
    ) ??
    (isNonEmptyString(ownerRecord?.['displayName'])
        ? `${ownerRecord!['displayName']} Twitch`
        : 'Video Twitch');

  return {
    title,
    normalizedUrl: `https://www.twitch.tv/videos/${videoId}`,
    status: 'ended',
    provider: 'twitch',
    suggestedPlayedOn: isoDatePart(publishedAt) ?? todayIsoDate(),
    endedAt: normalizeDateValue(publishedAt),
    ...(debug
        ? {
            debug: {
              inputUrl: url.toString(),
              videoId,
              ownerDisplayName: ownerRecord?.['displayName'] ?? null,
              ownerLogin: ownerRecord?.['login'] ?? null,
              publishedAt,
              broadcastType: videoRecord['broadcastType'] ?? null,
            },
          }
        : {}),
  };
}

async function fetchTwitchChannelMetadata(
  url: URL,
  login: string,
  debug = false,
): Promise<StreamMetadata> {
  const response = await postJson(
    'https://gql.twitch.tv/gql',
    {
      query: `
        query {
          user(login: ${graphqlString(login)}) {
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
      `,
    },
    {
      'Client-ID': twitchClientId,
      Accept: '*/*',
    },
  );

  const data = response?.['data'];
  const user = data && typeof data === 'object'
    ? (data as Record<string, unknown>)['user']
    : null;

  if (user == null || typeof user !== 'object') {
    throw new Error('Impossibile leggere i dati del canale Twitch');
  }

  const userRecord = user as Record<string, unknown>;
  const stream = userRecord['stream'];
  const displayName = isNonEmptyString(userRecord['displayName'])
    ? userRecord['displayName']
    : login;

  if (stream == null || typeof stream !== 'object') {
    return {
      title: `${displayName} su Twitch`,
      normalizedUrl: `https://www.twitch.tv/${login}`,
      status: 'unknown',
      provider: 'twitch',
      suggestedPlayedOn: todayIsoDate(),
      endedAt: null,
      ...(debug
          ? {
              debug: {
                inputUrl: url.toString(),
                login,
                displayName,
                streamType: null,
              },
            }
          : {}),
    };
  }

  const streamRecord = stream as Record<string, unknown>;
  const createdAt = isNonEmptyString(streamRecord['createdAt'])
    ? streamRecord['createdAt']
    : null;
  const title =
    cleanTwitchTitle(
      streamRecord['title']?.toString(),
      displayName,
      userRecord['login']?.toString(),
    ) ??
    `${displayName} live su Twitch`;

  return {
    title,
    normalizedUrl: `https://www.twitch.tv/${login}`,
    status: 'live',
    provider: 'twitch',
    suggestedPlayedOn: isoDatePart(createdAt) ?? todayIsoDate(),
    endedAt: null,
    ...(debug
        ? {
            debug: {
              inputUrl: url.toString(),
              login,
              displayName,
              createdAt,
              streamType: streamRecord['type'] ?? null,
            },
          }
        : {}),
  };
}

async function fetchGenericMetadata(url: URL, debug = false): Promise<StreamMetadata> {
  const html = await fetchHtml(url.toString());
  const jsonLdObjects = extractJsonLdObjects(html);
  const videoJsonLd = findJsonLdObject(jsonLdObjects, 'VideoObject');
  const broadcastJsonLd = findJsonLdObject(jsonLdObjects, 'BroadcastEvent');
  const ogTitle = extractMetaContent(html, 'property', 'og:title');
  const publishedAt =
    readJsonLdString(videoJsonLd, 'endDate', 'startDate', 'uploadDate', 'datePublished') ??
    readJsonLdString(broadcastJsonLd, 'endDate', 'startDate') ??
    extractMetaContent(html, 'property', 'article:published_time') ??
    extractMetaContent(html, 'property', 'og:updated_time') ??
    extractMetaContent(html, 'name', 'datePublished') ??
    extractMetaContent(html, 'name', 'uploadDate') ??
    extractAttributeContent(html, 'meta', 'itemprop', 'datePublished') ??
    extractAttributeContent(html, 'meta', 'itemprop', 'uploadDate');
  const canonicalUrl =
    extractMetaContent(html, 'property', 'og:url') ??
    extractMetaContent(html, 'name', 'twitter:url') ??
    url.toString();
  const title =
    cleanStreamTitle(ogTitle) ??
    cleanStreamTitle(readJsonLdString(videoJsonLd, 'name', 'headline')) ??
    cleanStreamTitle(extractTitleTag(html)) ??
    (isTikTokHost(url.hostname) ? 'Contenuto TikTok' : url.hostname);
  const provider =
    isTikTokHost(url.hostname)
      ? 'tiktok'
      : url.hostname.replace(/^www\./, '').split('.')[0] || 'web';

  return {
    title,
    normalizedUrl: canonicalUrl,
    status: 'unknown',
    provider,
    suggestedPlayedOn: isoDatePart(publishedAt) ?? todayIsoDate(),
    endedAt: null,
    ...(debug
        ? {
            debug: {
              htmlTitle: extractTitleTag(html),
              publishedAt,
              htmlPreview: html.slice(0, 500),
            },
          }
        : {}),
  };
}

async function fetchTikTokMetadata(
  url: URL,
  debug = false,
): Promise<StreamMetadata> {
  const metadata = await fetchGenericMetadata(url, debug);
  return {
    ...metadata,
    title: metadata.title.trim() || 'Contenuto TikTok',
    provider: 'tiktok',
    status: metadata.status === 'ended' ? 'unknown' : metadata.status,
    endedAt: null,
  };
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (request.method !== 'POST') {
    return jsonResponse({ error: 'Metodo non supportato' }, 405);
  }

  try {
    const body = await request.json();
    const rawUrl = body?.url?.toString() ?? '';
    const debug = body?.debug === true;
    const url = normalizeUrl(rawUrl);
    const youtubeVideoId = extractYouTubeVideoId(url);
    const twitchVideoId = extractTwitchVideoId(url);
    const twitchChannelLogin = extractTwitchChannelLogin(url);
    const isTikTok = isTikTokHost(url.hostname);

    const metadata = youtubeVideoId != null
      ? await fetchYouTubeMetadata(url, youtubeVideoId, debug)
      : twitchVideoId != null
          ? await fetchTwitchVideoMetadata(url, twitchVideoId, debug)
          : twitchChannelLogin != null
              ? await fetchTwitchChannelMetadata(url, twitchChannelLogin, debug)
              : isTikTok
                ? await fetchTikTokMetadata(url, debug)
                : await fetchGenericMetadata(url, debug);

    return jsonResponse(metadata);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Errore nel recupero metadata';
    return jsonResponse({ error: message }, 400);
  }
});
