import { Router } from 'express';
import { z } from 'zod';

import { supabaseDb } from '../lib/supabase';
import { asyncHandler } from '../middleware/async-handler';
import { requireAuth } from '../middleware/auth';
import { sendOk } from '../lib/http';
import { TeamInfoService } from '../services/team-info.service';

const teamInfoSchema = z.object({
  id: z.number().int().optional(),
  team_name: z.string().min(1),
  crest_url: z.string().url().nullable().optional(),
  website_url: z.string().url().nullable().optional(),
  youtube_url: z.string().url().nullable().optional(),
  discord_url: z.string().url().nullable().optional(),
  facebook_url: z.string().url().nullable().optional(),
  instagram_url: z.string().url().nullable().optional(),
  twitch_url: z.string().url().nullable().optional(),
  tiktok_url: z.string().url().nullable().optional(),
  additional_links: z
    .array(
      z.object({
        label: z.string().min(1),
        url: z.string().url(),
      }),
    )
    .default([]),
  updated_at: z.string().nullable().optional(),
});

export const teamInfoRouter = Router();
const teamInfoService = new TeamInfoService(supabaseDb);

teamInfoRouter.get(
  '/',
  asyncHandler(async (_req, res) => {
    const teamInfo = await teamInfoService.getTeamInfo();
    sendOk(res, { teamInfo });
  }),
);

teamInfoRouter.put(
  '/',
  requireAuth,
  asyncHandler(async (req, res) => {
    const principal = req.principal;
    const parsedTeamInfo = teamInfoSchema.parse(req.body);
    const teamInfo = await teamInfoService.updateTeamInfo(
      {
        ...parsedTeamInfo,
        id: 1,
        crest_url: parsedTeamInfo.crest_url ?? null,
        website_url: parsedTeamInfo.website_url ?? null,
        youtube_url: parsedTeamInfo.youtube_url ?? null,
        discord_url: parsedTeamInfo.discord_url ?? null,
        facebook_url: parsedTeamInfo.facebook_url ?? null,
        instagram_url: parsedTeamInfo.instagram_url ?? null,
        twitch_url: parsedTeamInfo.twitch_url ?? null,
        tiktok_url: parsedTeamInfo.tiktok_url ?? null,
      },
      principal!,
    );
    sendOk(res, { teamInfo });
  }),
);
