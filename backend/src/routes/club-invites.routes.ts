import type { SupabaseClient } from '@supabase/supabase-js';
import type { RequestHandler } from 'express';
import { Router } from 'express';

import type {
  ClubInviteListResultDto,
  ClubInviteRow,
  ClubRow,
} from '../domain/types';
import { sendCreated, sendOk } from '../lib/http';
import { publishRealtimeChange } from '../lib/realtime-publisher';
import { supabaseDb } from '../lib/supabase';
import { asyncHandler } from '../middleware/async-handler';
import { requireAuth } from '../middleware/auth';
import { InvitesService } from '../services/invites.service';
import {
  createInviteSchema,
  inviteCandidatesQuerySchema,
  inviteIdParamSchema,
  inviteListQuerySchema,
} from '../validation/invites.validation';

type ClubInvitesRouterOptions = {
  db?: SupabaseClient;
  authMiddleware?: RequestHandler;
  publishChange?: typeof publishRealtimeChange;
};

function serializeInviteClub(club: ClubRow | null | undefined): Record<string, unknown> | null {
  if (!club) {
    return null;
  }

  return {
    id: club.id,
    name: club.name,
    normalized_name: club.normalized_name,
    slug: club.slug,
    logo_url: club.logo_url,
    primary_color: club.primary_color,
    accent_color: club.accent_color,
    surface_color: club.surface_color,
  };
}

function serializeInvite(invite: ClubInviteRow): Record<string, unknown> {
  return {
    ...invite,
    club: serializeInviteClub(invite.club),
  };
}

function serializeInviteListResult(result: ClubInviteListResultDto): Record<string, unknown> {
  return {
    invites: result.invites.map((invite) => serializeInvite(invite)),
    pagination: result.pagination,
  };
}

export function createClubInvitesRouter(
  options: ClubInvitesRouterOptions = {},
): Router {
  const router = Router();
  const authMiddleware = options.authMiddleware ?? requireAuth;
  const publishChange = options.publishChange ?? publishRealtimeChange;
  const invitesService = new InvitesService(options.db ?? supabaseDb);

  router.get(
    '/candidates',
    authMiddleware,
    asyncHandler(async (req, res) => {
      const candidates = await invitesService.listCandidates(
        inviteCandidatesQuerySchema.parse(req.query),
        req.principal!,
      );
      sendOk(res, { candidates });
    }),
  );

  router.post(
    '/',
    authMiddleware,
    asyncHandler(async (req, res) => {
      const invite = await invitesService.createInvite(
        createInviteSchema.parse(req.body),
        req.principal!,
      );
      publishChange(['invites', 'notifications'], 'club_invite_created');
      sendCreated(res, { invite: serializeInvite(invite) });
    }),
  );

  router.get(
    '/sent',
    authMiddleware,
    asyncHandler(async (req, res) => {
      const result = await invitesService.listSentInvites(
        inviteListQuerySchema.parse(req.query),
        req.principal!,
      );
      sendOk(res, serializeInviteListResult(result));
    }),
  );

  router.get(
    '/received',
    authMiddleware,
    asyncHandler(async (req, res) => {
      const result = await invitesService.listReceivedInvites(
        inviteListQuerySchema.parse(req.query),
        req.principal!,
      );
      sendOk(res, serializeInviteListResult(result));
    }),
  );

  router.post(
    '/:id/revoke',
    authMiddleware,
    asyncHandler(async (req, res) => {
      const { id } = inviteIdParamSchema.parse(req.params);
      const invite = await invitesService.revokeInvite(id, req.principal!);
      publishChange(['invites', 'notifications'], 'club_invite_revoked');
      sendOk(res, { invite: serializeInvite(invite) });
    }),
  );

  router.post(
    '/:id/accept',
    authMiddleware,
    asyncHandler(async (req, res) => {
      const { id } = inviteIdParamSchema.parse(req.params);
      const result = await invitesService.acceptInvite(id, req.principal!);
      publishChange(
        ['invites', 'notifications', 'players', 'clubs'],
        'club_invite_accepted',
      );
      sendOk(res, {
        ...result,
        invite: serializeInvite(result.invite),
      });
    }),
  );

  router.post(
    '/:id/decline',
    authMiddleware,
    asyncHandler(async (req, res) => {
      const { id } = inviteIdParamSchema.parse(req.params);
      const invite = await invitesService.declineInvite(id, req.principal!);
      publishChange(['invites', 'notifications'], 'club_invite_declined');
      sendOk(res, { invite: serializeInvite(invite) });
    }),
  );

  return router;
}

export const clubInvitesRouter = createClubInvitesRouter();
