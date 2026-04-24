import type { SupabaseClient } from '@supabase/supabase-js';

import type { ClubInfoRow, ClubRow, RequestPrincipal } from '../domain/types';
import { ConflictError, ForbiddenError } from '../lib/errors';
import { optionalData, requiredData } from '../lib/supabase-result';

function normalizeText(value: string | null | undefined): string | null {
  const normalized = value?.trim() ?? '';
  return normalized.length > 0 ? normalized : null;
}

function normalizeClubName(value: string): string {
  const normalized = value.trim().replaceAll(/\s+/g, ' ');
  if (normalized.length === 0) {
    throw new ConflictError('Il nome club non puo essere vuoto');
  }

  return normalized;
}

function normalizeClubKey(value: string): string {
  return normalizeClubName(value).toLowerCase();
}

function slugifyClubName(value: string): string {
  const slug = normalizeClubName(value)
    .toLowerCase()
    .replaceAll(/[^a-z0-9]+/g, '-')
    .replaceAll(/-{2,}/g, '-')
    .replaceAll(/^-|-$/g, '');

  return slug.length === 0 ? 'club' : slug;
}

function normalizeHexColor(value: string | null | undefined): string | null {
  const normalized = normalizeText(value);
  if (!normalized) {
    return null;
  }

  const hex = normalized.startsWith('#') ? normalized : `#${normalized}`;
  if (!/^#[0-9a-fA-F]{6}$/.test(hex)) {
    throw new ConflictError('I colori del club devono essere esadecimali');
  }

  return hex.toUpperCase();
}

export class ClubInfoService {
  constructor(private readonly db: SupabaseClient) {}

  async getClubInfo(principal: RequestPrincipal): Promise<ClubInfoRow> {
    if (!principal.membership || !principal.club) {
      throw new ForbiddenError('Devi appartenere a un club per vedere queste informazioni');
    }

    const settingsResponse = await this.db
      .from('club_settings')
      .select('*')
      .eq('club_id', principal.club.id)
      .maybeSingle();

    const settings = optionalData(settingsResponse) as {
      website_url: string | null;
      youtube_url: string | null;
      discord_url: string | null;
      facebook_url: string | null;
      instagram_url: string | null;
      twitch_url: string | null;
      tiktok_url: string | null;
      additional_links: Array<{ label: string; url: string }>;
      updated_at?: string | null;
    } | null;

    return {
      id: principal.club.id,
      club_name: principal.club.name,
      crest_url: principal.club.logo_url,
      website_url: settings?.website_url ?? null,
      youtube_url: settings?.youtube_url ?? null,
      discord_url: settings?.discord_url ?? null,
      facebook_url: settings?.facebook_url ?? null,
      instagram_url: settings?.instagram_url ?? null,
      twitch_url: settings?.twitch_url ?? null,
      tiktok_url: settings?.tiktok_url ?? null,
      additional_links: settings?.additional_links ?? [],
      primary_color: principal.club.primary_color,
      accent_color: principal.club.accent_color,
      surface_color: principal.club.surface_color,
      slug: principal.club.slug,
      updated_at: settings?.updated_at ?? principal.club.updated_at ?? null,
    };
  }

  async updateClubInfo(clubInfo: ClubInfoRow, principal: RequestPrincipal): Promise<ClubInfoRow> {
    if (!principal.membership || !principal.club) {
      throw new ForbiddenError('Devi appartenere a un club per modificare queste informazioni');
    }
    if (!principal.canManageClubInfo) {
      throw new ForbiddenError('Non puoi modificare le info del club');
    }

    const clubName = normalizeClubName(clubInfo.club_name);
    const normalizedName = normalizeClubKey(clubName);
    await this.ensureUniqueClubName(normalizedName, principal.club.id);
    const slug = await this.resolveUniqueSlug(principal.club, clubName);

    const clubResponse = await this.db
      .from('clubs')
      .update({
        name: clubName,
        normalized_name: normalizedName,
        slug,
        logo_url: normalizeText(clubInfo.crest_url) ?? principal.club.logo_url,
        primary_color: normalizeHexColor(clubInfo.primary_color) ?? principal.club.primary_color,
        accent_color: normalizeHexColor(clubInfo.accent_color) ?? principal.club.accent_color,
        surface_color: normalizeHexColor(clubInfo.surface_color) ?? principal.club.surface_color,
      })
      .eq('id', principal.club.id)
      .select('*')
      .single();

    const club = requiredData(clubResponse) as ClubRow;

    const settingsResponse = await this.db
      .from('club_settings')
      .upsert(
        {
          club_id: principal.club.id,
          website_url: normalizeText(clubInfo.website_url),
          youtube_url: normalizeText(clubInfo.youtube_url),
          discord_url: normalizeText(clubInfo.discord_url),
          facebook_url: normalizeText(clubInfo.facebook_url),
          instagram_url: normalizeText(clubInfo.instagram_url),
          twitch_url: normalizeText(clubInfo.twitch_url),
          tiktok_url: normalizeText(clubInfo.tiktok_url),
          additional_links: clubInfo.additional_links ?? [],
        },
        { onConflict: 'club_id' },
      )
      .select('*')
      .single();

    const settings = requiredData(settingsResponse) as {
      website_url: string | null;
      youtube_url: string | null;
      discord_url: string | null;
      facebook_url: string | null;
      instagram_url: string | null;
      twitch_url: string | null;
      tiktok_url: string | null;
      additional_links: Array<{ label: string; url: string }>;
      updated_at?: string | null;
    };

    return {
      id: club.id,
      club_name: club.name,
      crest_url: club.logo_url,
      website_url: settings.website_url,
      youtube_url: settings.youtube_url,
      discord_url: settings.discord_url,
      facebook_url: settings.facebook_url,
      instagram_url: settings.instagram_url,
      twitch_url: settings.twitch_url,
      tiktok_url: settings.tiktok_url,
      additional_links: settings.additional_links,
      primary_color: club.primary_color,
      accent_color: club.accent_color,
      surface_color: club.surface_color,
      slug: club.slug,
      updated_at: settings.updated_at ?? club.updated_at ?? null,
    };
  }

  private async ensureUniqueClubName(
    normalizedName: string,
    excludingClubId: string | number,
  ): Promise<void> {
    const response = await this.db
      .from('clubs')
      .select('id')
      .eq('normalized_name', normalizedName)
      .neq('id', excludingClubId)
      .limit(1)
      .maybeSingle();

    if (optionalData(response) != null) {
      throw new ConflictError('Esiste gia un club con questo nome');
    }
  }

  private async resolveUniqueSlug(currentClub: ClubRow, nextName: string): Promise<string> {
    const baseSlug = slugifyClubName(nextName);
    if (baseSlug === currentClub.slug) {
      return baseSlug;
    }

    const response = await this.db
      .from('clubs')
      .select('slug')
      .or(`slug.eq.${baseSlug},slug.like.${baseSlug}-%`)
      .neq('id', currentClub.id);

    const existingSlugs = new Set(
      ((optionalData(response) as Array<{ slug?: string }> | null) ?? [])
        .map((row) => row.slug?.trim())
        .filter((value): value is string => Boolean(value)),
    );

    if (!existingSlugs.has(baseSlug)) {
      return baseSlug;
    }

    let suffix = 2;
    while (existingSlugs.has(`${baseSlug}-${suffix}`)) {
      suffix += 1;
    }

    return `${baseSlug}-${suffix}`;
  }
}
