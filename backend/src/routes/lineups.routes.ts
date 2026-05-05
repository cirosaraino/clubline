import type { SupabaseClient } from '@supabase/supabase-js';
import type { RequestHandler } from 'express';
import { Router } from 'express';
import { z } from 'zod';

import { sendCreated, sendNoContent, sendOk } from '../lib/http';
import { publishRealtimeChange } from '../lib/realtime-publisher';
import { supabaseDb } from '../lib/supabase';
import { asyncHandler } from '../middleware/async-handler';
import { requireAuth } from '../middleware/auth';
import { ClubNotificationPublisherService } from '../services/club-notification-publisher.service';
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

const deleteLineupsByIdsSchema = z.object({
  lineup_ids: z.array(z.union([z.string().min(1), z.number()])).min(1),
});

type LineupsRouterOptions = {
  db?: SupabaseClient;
  authMiddleware?: RequestHandler;
  publishChange?: typeof publishRealtimeChange;
};

export function createLineupsRouter(
  options: LineupsRouterOptions = {},
): Router {
  const router = Router();
  const db = options.db ?? supabaseDb;
  const authMiddleware = options.authMiddleware ?? requireAuth;
  const publishChange = options.publishChange ?? publishRealtimeChange;
  const lineupsService = new LineupsService(db);
  const notificationsPublisher = new ClubNotificationPublisherService(db);

  router.get(
    '/',
    authMiddleware,
    asyncHandler(async (_req, res) => {
      const lineups = await lineupsService.listLineups(_req.principal!);
      sendOk(res, { lineups });
    }),
  );

  router.get(
    '/assignments',
    authMiddleware,
    asyncHandler(async (req, res) => {
      const rawIds = typeof req.query.lineup_ids === 'string' ? req.query.lineup_ids : '';
      const lineupIds = rawIds
        .split(',')
        .map((value) => value.trim())
        .filter(Boolean);

      const assignments = await lineupsService.listAssignmentsForLineups(lineupIds, req.principal!);
      sendOk(res, { assignments });
    }),
  );

  router.post(
    '/',
    authMiddleware,
    asyncHandler(async (req, res) => {
      const lineup = await lineupsService.createLineup(
        lineupInputSchema.parse(req.body),
        req.principal!,
      );
      publishChange(['lineups', 'attendance'], 'lineup_created');
      sendCreated(res, { lineup });
    }),
  );

  router.get(
    '/:id/players',
    authMiddleware,
    asyncHandler(async (req, res) => {
      const assignments = await lineupsService.listLineupPlayers(req.params.id, req.principal!);
      sendOk(res, { assignments });
    }),
  );

  router.put(
    '/:id/players',
    authMiddleware,
    asyncHandler(async (req, res) => {
      const { assignments } = lineupAssignmentsSchema.parse(req.body);
      const lineup = await lineupsService.replaceLineupPlayers(
        req.params.id,
        assignments,
        req.principal!,
      );

      if (assignments.length > 0) {
        await notificationsPublisher.publishLineupPublished({
          clubId: lineup.club_id,
          clubName: req.principal?.club?.name,
          lineup,
        });
        publishChange(['lineups', 'attendance', 'notifications'], 'lineup_players_updated');
      } else {
        publishChange(['lineups', 'attendance'], 'lineup_players_updated');
      }

      sendNoContent(res);
    }),
  );

  router.put(
    '/:id',
    authMiddleware,
    asyncHandler(async (req, res) => {
      const lineup = await lineupsService.updateLineup(
        req.params.id,
        lineupInputSchema.parse(req.body),
        req.principal!,
      );
      publishChange(['lineups', 'attendance'], 'lineup_updated');
      sendOk(res, { lineup });
    }),
  );

  router.delete(
    '/all',
    authMiddleware,
    asyncHandler(async (req, res) => {
      await lineupsService.deleteAllLineups(req.principal!);
      publishChange(['lineups', 'attendance'], 'lineup_deleted_all');
      sendNoContent(res);
    }),
  );

  router.delete(
    '/day',
    authMiddleware,
    asyncHandler(async (req, res) => {
      const { lineup_ids: lineupIds } = deleteLineupsByIdsSchema.parse(req.body);
      await lineupsService.deleteLineupsByIds(lineupIds, req.principal!);
      publishChange(['lineups', 'attendance'], 'lineup_deleted_day');
      sendNoContent(res);
    }),
  );

  router.delete(
    '/:id',
    authMiddleware,
    asyncHandler(async (req, res) => {
      await lineupsService.deleteLineup(req.params.id, req.principal!);
      publishChange(['lineups', 'attendance'], 'lineup_deleted');
      sendNoContent(res);
    }),
  );

  return router;
}

export const lineupsRouter = createLineupsRouter();
