import { Router } from 'express';
import { z } from 'zod';

import { supabaseDb } from '../lib/supabase';
import { asyncHandler } from '../middleware/async-handler';
import { requireAuth } from '../middleware/auth';
import { sendCreated, sendNoContent, sendOk } from '../lib/http';
import { realtimeEventsBus } from '../lib/realtime-events';
import { PlayerService } from '../services/player.service';

const playerInputSchema = z.object({
  nome: z.string().min(1),
  cognome: z.string().min(1),
  account_email: z.string().email().nullable().optional(),
  shirt_number: z.number().int().nullable().optional(),
  primary_role: z.string().nullable().optional(),
  secondary_role: z.string().nullable().optional(),
  secondary_roles: z.array(z.string()).nullable().optional(),
  id_console: z.string().min(1).nullable().optional(),
  team_role: z.enum(['captain', 'vice_captain', 'player']).nullable().optional(),
});

export const playersRouter = Router();
const playerService = new PlayerService(supabaseDb);

playersRouter.get(
  '/',
  asyncHandler(async (req, res) => {
    const players = await playerService.listPlayers({
      macro_role: typeof req.query.macro_role === 'string' ? req.query.macro_role : undefined,
      role: typeof req.query.role === 'string' ? req.query.role : undefined,
      id_console: typeof req.query.id_console === 'string' ? req.query.id_console : undefined,
      nome: typeof req.query.nome === 'string' ? req.query.nome : undefined,
      cognome: typeof req.query.cognome === 'string' ? req.query.cognome : undefined,
      q: typeof req.query.q === 'string' ? req.query.q : undefined,
    });

    sendOk(res, { players });
  }),
);

playersRouter.get(
  '/by-console/:consoleId',
  asyncHandler(async (req, res) => {
    const player = await playerService.findByConsoleId(req.params.consoleId);
    if (!player) {
      res.status(404).json({
        error: {
          message: 'Giocatore non trovato',
        },
      });
      return;
    }

    sendOk(res, { player });
  }),
);

playersRouter.post(
  '/',
  requireAuth,
  asyncHandler(async (req, res) => {
    const principal = req.principal;
    const player = await playerService.createPlayer(playerInputSchema.parse(req.body), principal!);
    realtimeEventsBus.publishChange(['players', 'attendance', 'lineups'], 'player_created');
    sendCreated(res, { player });
  }),
);

playersRouter.post(
  '/claim',
  requireAuth,
  asyncHandler(async (req, res) => {
    const principal = req.principal;
    const player = await playerService.claimProfile(playerInputSchema.parse(req.body), principal!);
    realtimeEventsBus.publishChange(['players', 'attendance', 'lineups'], 'player_claimed');
    sendCreated(res, { player });
  }),
);

const updatePlayerHandler = asyncHandler(async (req, res) => {
  const principal = req.principal;
  const player = await playerService.updatePlayer(req.params.id, playerInputSchema.parse(req.body), principal!);
  realtimeEventsBus.publishChange(['players', 'attendance', 'lineups'], 'player_updated');
  sendOk(res, { player });
});

playersRouter.patch(
  '/:id',
  requireAuth,
  updatePlayerHandler,
);

playersRouter.put(
  '/:id',
  requireAuth,
  updatePlayerHandler,
);

playersRouter.delete(
  '/:id',
  requireAuth,
  asyncHandler(async (req, res) => {
    const principal = req.principal;
    await playerService.deletePlayer(req.params.id, principal!);
    realtimeEventsBus.publishChange(['players', 'attendance', 'lineups'], 'player_deleted');
    sendNoContent(res);
  }),
);

playersRouter.get(
  '/me',
  requireAuth,
  asyncHandler(async (req, res) => {
    const principal = req.principal;
    if (!principal?.player) {
      sendOk(res, { player: null });
      return;
    }

    sendOk(res, { player: principal.player });
  }),
);
