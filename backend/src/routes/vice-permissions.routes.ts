import { Router } from 'express';
import { z } from 'zod';

import { supabaseDb } from '../lib/supabase';
import { asyncHandler } from '../middleware/async-handler';
import { requireAuth } from '../middleware/auth';
import { sendOk } from '../lib/http';
import { publishRealtimeChange } from '../lib/realtime-publisher';
import { VicePermissionsService } from '../services/vice-permissions.service';

const permissionsSchema = z.object({
  vice_manage_players: z.boolean().default(false),
  vice_manage_lineups: z.boolean().default(false),
  vice_manage_streams: z.boolean().default(false),
  vice_manage_attendance: z.boolean().default(false),
  vice_manage_invites: z.boolean().default(false),
  vice_manage_team_info: z.boolean().default(false),
  updated_at: z.string().nullable().optional(),
});

export const vicePermissionsRouter = Router();
const vicePermissionsService = new VicePermissionsService(supabaseDb);

vicePermissionsRouter.get(
  '/',
  requireAuth,
  asyncHandler(async (req, res) => {
    const permissions = await vicePermissionsService.getPermissions(req.principal!);
    sendOk(res, { permissions });
  }),
);

vicePermissionsRouter.put(
  '/',
  requireAuth,
  asyncHandler(async (req, res) => {
    const principal = req.principal;
    const parsedPermissions = permissionsSchema.parse(req.body);
    const permissions = await vicePermissionsService.updatePermissions(
      {
        club_id: principal!.membership?.club_id ?? 0,
        ...parsedPermissions,
      },
      principal!,
    );
    publishRealtimeChange(['vicePermissions', 'players'], 'vice_permissions_updated');
    sendOk(res, { permissions });
  }),
);
