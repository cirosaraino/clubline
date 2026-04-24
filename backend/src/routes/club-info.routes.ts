import { Router } from 'express';
import { z } from 'zod';

import { supabaseDb } from '../lib/supabase';
import { asyncHandler } from '../middleware/async-handler';
import { requireAuth } from '../middleware/auth';
import { sendOk } from '../lib/http';
import { publishRealtimeChange } from '../lib/realtime-publisher';
import { ClubInfoService } from '../services/club-info.service';

const clubInfoSchema = z
  .object({
  id: z.number().int().optional(),
  club_name: z.string().min(1).optional(),
  team_name: z.string().min(1).optional(),
  crest_url: z.string().url().nullable().optional(),
  website_url: z.string().url().nullable().optional(),
  youtube_url: z.string().url().nullable().optional(),
  discord_url: z.string().url().nullable().optional(),
  facebook_url: z.string().url().nullable().optional(),
  instagram_url: z.string().url().nullable().optional(),
  twitch_url: z.string().url().nullable().optional(),
  tiktok_url: z.string().url().nullable().optional(),
  primary_color: z.string().nullable().optional(),
  accent_color: z.string().nullable().optional(),
  surface_color: z.string().nullable().optional(),
  slug: z.string().nullable().optional(),
  additional_links: z
    .array(
      z.object({
        label: z.string().min(1),
        url: z.string().url(),
      }),
    )
    .default([]),
  updated_at: z.string().nullable().optional(),
})
  .transform(({ team_name, club_name, ...rest }) => ({
    ...rest,
    club_name: club_name ?? team_name ?? '',
  }));

export const clubInfoRouter = Router();
const clubInfoService = new ClubInfoService(supabaseDb);

clubInfoRouter.get(
  '/',
  requireAuth,
  asyncHandler(async (req, res) => {
    const clubInfo = await clubInfoService.getClubInfo(req.principal!);
    sendOk(res, { clubInfo, teamInfo: clubInfo });
  }),
);

clubInfoRouter.put(
  '/',
  requireAuth,
  asyncHandler(async (req, res) => {
    const principal = req.principal;
    const parsedClubInfo = clubInfoSchema.parse(req.body);
    const clubInfo = await clubInfoService.updateClubInfo(
      {
        ...parsedClubInfo,
        id: req.principal!.membership!.club_id,
        crest_url: parsedClubInfo.crest_url ?? null,
        website_url: parsedClubInfo.website_url ?? null,
        youtube_url: parsedClubInfo.youtube_url ?? null,
        discord_url: parsedClubInfo.discord_url ?? null,
        facebook_url: parsedClubInfo.facebook_url ?? null,
        instagram_url: parsedClubInfo.instagram_url ?? null,
        twitch_url: parsedClubInfo.twitch_url ?? null,
        tiktok_url: parsedClubInfo.tiktok_url ?? null,
        primary_color: parsedClubInfo.primary_color ?? null,
        accent_color: parsedClubInfo.accent_color ?? null,
        surface_color: parsedClubInfo.surface_color ?? null,
        slug: parsedClubInfo.slug ?? null,
      },
      principal!,
    );
    publishRealtimeChange(['clubInfo'], 'club_info_updated');
    sendOk(res, { clubInfo, teamInfo: clubInfo });
  }),
);
