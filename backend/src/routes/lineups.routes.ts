import { Router } from 'express';
import { z } from 'zod';

import { supabaseDb } from '../lib/supabase';
import { sendCreated, sendNoContent, sendOk } from '../lib/http';
import { realtimeEventsBus } from '../lib/realtime-events';
import { asyncHandler } from '../middleware/async-handler';
import { requireAuth } from '../middleware/auth';
import { LineupsService } from '../services/lineups.service';

const lineupInputSchema = z.object({
  competition_name: z.string().min(1),
  match_datetime: z.string().min(1),
  opponent_name: z.string().nullable().optional(),
  formation_module: z.string().min(1),
  notes: z.string().nullable().optional(),
});

const lineupAssignmentsSchema = z.object({
  assignments: z.array(
    z.object({
      player_id: z.union([z.string().min(1), z.number()]),
      position_code: z.string().min(1),
    }),
  ),
});

export const lineupsRouter = Router();
const lineupsService = new LineupsService(supabaseDb);

lineupsRouter.get(
  '/',
  asyncHandler(async (_req, res) => {
    const lineups = await lineupsService.listLineups();
    sendOk(res, { lineups });
  }),
);

lineupsRouter.get(
  '/assignments',
  asyncHandler(async (req, res) => {
    const rawIds = typeof req.query.lineup_ids === 'string' ? req.query.lineup_ids : '';
    const lineupIds = rawIds
      .split(',')
      .map((value) => value.trim())
      .filter(Boolean);

    const assignments = await lineupsService.listAssignmentsForLineups(lineupIds);
    sendOk(res, { assignments });
  }),
);

lineupsRouter.post(
  '/',
  requireAuth,
  asyncHandler(async (req, res) => {
    const lineup = await lineupsService.createLineup(
      lineupInputSchema.parse(req.body),
      req.principal!,
    );
    realtimeEventsBus.publishChange(['lineups', 'attendance'], 'lineup_created');
    sendCreated(res, { lineup });
  }),
);

lineupsRouter.get(
  '/:id/players',
  asyncHandler(async (req, res) => {
    const assignments = await lineupsService.listLineupPlayers(req.params.id);
    sendOk(res, { assignments });
  }),
);

lineupsRouter.put(
  '/:id/players',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { assignments } = lineupAssignmentsSchema.parse(req.body);
    await lineupsService.replaceLineupPlayers(req.params.id, assignments, req.principal!);
    realtimeEventsBus.publishChange(['lineups', 'attendance'], 'lineup_players_updated');
    sendNoContent(res);
  }),
);

lineupsRouter.put(
  '/:id',
  requireAuth,
  asyncHandler(async (req, res) => {
    const lineup = await lineupsService.updateLineup(
      req.params.id,
      lineupInputSchema.parse(req.body),
      req.principal!,
    );
    realtimeEventsBus.publishChange(['lineups', 'attendance'], 'lineup_updated');
    sendOk(res, { lineup });
  }),
);

lineupsRouter.delete(
  '/all',
  requireAuth,
  asyncHandler(async (req, res) => {
    await lineupsService.deleteAllLineups(req.principal!);
    realtimeEventsBus.publishChange(['lineups', 'attendance'], 'lineup_deleted_all');
    sendNoContent(res);
  }),
);

lineupsRouter.delete(
  '/:id',
  requireAuth,
  asyncHandler(async (req, res) => {
    await lineupsService.deleteLineup(req.params.id, req.principal!);
    realtimeEventsBus.publishChange(['lineups', 'attendance'], 'lineup_deleted');
    sendNoContent(res);
  }),
);
