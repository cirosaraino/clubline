import { Router } from 'express';

import { env } from '../config/env';
import { supabaseAuth, supabaseDb } from '../lib/supabase';
import { asyncHandler } from '../middleware/async-handler';
import { createRateLimitMiddleware } from '../middleware/rate-limit';
import { requireAuth } from '../middleware/auth';
import { sendCreated, sendNoContent, sendOk } from '../lib/http';
import { AccessService } from '../services/access.service';
import { AuthService } from '../services/auth.service';
import { ClubsService } from '../services/clubs.service';
import {
  credentialsSchema,
  passwordResetRequestSchema,
  passwordUpdateSchema,
  refreshSchema,
} from '../validation/auth.validation';

const authService = new AuthService(supabaseAuth, supabaseDb);
const accessService = new AccessService(supabaseDb);
const clubsService = new ClubsService(supabaseDb);

async function countUnreadNotificationsForUser(userId: string): Promise<number> {
  const response = await supabaseDb
    .from('app_notifications')
    .select('id', { count: 'exact', head: true })
    .eq('recipient_user_id', userId)
    .is('read_at', null);

  if (response.error) {
    throw response.error;
  }

  return response.count ?? 0;
}

async function countPendingReceivedInvitesForUser(userId: string): Promise<number> {
  const response = await supabaseDb
    .from('club_invites')
    .select('id', { count: 'exact', head: true })
    .eq('target_user_id', userId)
    .eq('status', 'pending');

  if (response.error) {
    throw response.error;
  }

  return response.count ?? 0;
}

function extractNormalizedEmail(body: unknown): string {
  if (typeof body !== 'object' || body == null || Array.isArray(body)) {
    return 'unknown';
  }

  const rawEmail = (body as Record<string, unknown>).email;
  if (typeof rawEmail !== 'string') {
    return 'unknown';
  }

  const normalized = rawEmail.trim().toLowerCase();
  return normalized.length === 0 ? 'unknown' : normalized;
}

const loginRateLimit = createRateLimitMiddleware({
  keyPrefix: 'auth-login',
  windowMs: 15 * 60 * 1000,
  maxRequests: 10,
  keyGenerator: ({ ip, body }) => `${ip}:${extractNormalizedEmail(body)}`,
});

const registerRateLimit = createRateLimitMiddleware({
  keyPrefix: 'auth-register',
  windowMs: 60 * 60 * 1000,
  maxRequests: 5,
  keyGenerator: ({ ip, body }) => `${ip}:${extractNormalizedEmail(body)}`,
});

const passwordResetRateLimit = createRateLimitMiddleware({
  keyPrefix: 'auth-password-reset',
  windowMs: 60 * 60 * 1000,
  maxRequests: 5,
  keyGenerator: ({ ip, body }) => `${ip}:${extractNormalizedEmail(body)}`,
});

export const authRouter = Router();

authRouter.post(
  '/register',
  registerRateLimit,
  asyncHandler(async (req, res) => {
    const { email, password, redirectTo } = credentialsSchema.parse(req.body);
    const result = await authService.register(email, password, redirectTo);
    sendCreated(res, result);
  }),
);

authRouter.post(
  '/login',
  loginRateLimit,
  asyncHandler(async (req, res) => {
    const { email, password } = credentialsSchema.parse(req.body);
    const result = await authService.login(email, password);
    sendOk(res, result);
  }),
);

authRouter.post(
  '/refresh',
  asyncHandler(async (req, res) => {
    const { refreshToken } = refreshSchema.parse(req.body);
    const result = await authService.refresh(refreshToken);
    sendOk(res, result);
  }),
);

authRouter.post(
  '/request-password-reset',
  passwordResetRateLimit,
  asyncHandler(async (req, res) => {
    const { email, redirectTo } = passwordResetRequestSchema.parse(req.body);
    const result = await authService.requestPasswordReset(email, redirectTo);
    sendOk(res, result);
  }),
);

authRouter.post(
  '/update-password',
  requireAuth,
  asyncHandler(async (req, res) => {
    const principal = req.principal;
    if (!principal) {
      sendOk(res, {
        success: false,
        message: 'Sessione non valida',
      });
      return;
    }

    const { password } = passwordUpdateSchema.parse(req.body);
    const result = await authService.updatePassword(
      principal.authUser.id,
      password,
    );
    sendOk(res, result);
  }),
);

authRouter.post(
  '/logout',
  requireAuth,
  asyncHandler(async (req, res) => {
    const principal = req.principal;
    if (!principal) {
      sendOk(res, { success: true });
      return;
    }

    await authService.logout(principal.authUser.id);
    sendOk(res, { success: true });
  }),
);

authRouter.delete(
  '/account',
  requireAuth,
  asyncHandler(async (req, res) => {
    const principal = req.principal;
    if (!principal) {
      sendNoContent(res);
      return;
    }

    await authService.deleteAccount(principal.authUser.id);
    sendNoContent(res);
  }),
);

authRouter.get(
  '/public-config',
  asyncHandler(async (_req, res) => {
    sendOk(res, {
      environment: {
        appEnv: env.APP_ENV,
        nodeEnv: env.NODE_ENV,
      },
      supabase: {
        url: env.SUPABASE_URL,
        anonKey: env.SUPABASE_ANON_KEY,
      },
      realtime: {
        provider: 'supabase',
        localFallbackEnabled: env.ENABLE_LOCAL_REALTIME_FALLBACK,
      },
    });
  }),
);

authRouter.get(
  '/bootstrap-status',
  asyncHandler(async (_req, res) => {
    sendOk(res, {
      canBootstrapCaptainRegistration: false,
    });
  }),
);

authRouter.get(
  '/me',
  requireAuth,
  asyncHandler(async (req, res) => {
    const principal = req.principal;
    if (!principal) {
      sendOk(res, { user: null });
      return;
    }

    sendOk(res, {
      user: {
        id: principal.authUser.id,
        email: principal.authUser.email,
        emailVerified: principal.authUser.emailVerified,
        emailVerifiedAt: principal.authUser.emailVerifiedAt,
      },
    });
  }),
);

authRouter.get(
  '/session-state',
  requireAuth,
  asyncHandler(async (req, res) => {
    const principal = req.principal;
    if (!principal) {
      sendOk(res, { user: null });
      return;
    }

    const clubInfoPromise = principal.club
      ? accessService.getClubInfoForClub(principal.club.id)
      : Promise.resolve(null);
    const pendingJoinRequestPromise = clubsService.getCurrentPendingJoinRequest(
      principal.authUser.id,
    );
    const pendingLeaveRequestPromise = principal.membership
      ? clubsService.getCurrentPendingLeaveRequest(principal.membership.id)
      : Promise.resolve(null);
    const captainPendingJoinRequestsPromise = principal.isCaptain
      ? clubsService.listPendingJoinRequests(principal)
      : Promise.resolve([]);
    const captainPendingLeaveRequestsPromise = principal.isCaptain
      ? clubsService.listPendingLeaveRequests(principal)
      : Promise.resolve([]);
    const unreadNotificationsCountPromise = countUnreadNotificationsForUser(
      principal.authUser.id,
    );
    const pendingReceivedInvitesCountPromise =
      countPendingReceivedInvitesForUser(principal.authUser.id);

    const [
      clubInfo,
      pendingJoinRequest,
      pendingLeaveRequest,
      captainPendingJoinRequests,
      captainPendingLeaveRequests,
      unreadNotificationsCount,
      pendingReceivedInvitesCount,
    ] = await Promise.all([
      clubInfoPromise,
      pendingJoinRequestPromise,
      pendingLeaveRequestPromise,
      captainPendingJoinRequestsPromise,
      captainPendingLeaveRequestsPromise,
      unreadNotificationsCountPromise,
      pendingReceivedInvitesCountPromise,
    ]);

    sendOk(res, {
      user: {
        id: principal.authUser.id,
        email: principal.authUser.email,
        emailVerified: principal.authUser.emailVerified,
        emailVerifiedAt: principal.authUser.emailVerifiedAt,
      },
      membership: principal.membership,
      club: principal.club,
      currentPlayer: principal.player,
      vicePermissions: principal.permissions,
      clubInfo,
      pendingJoinRequest,
      pendingLeaveRequest,
      captainPendingJoinRequests,
      captainPendingLeaveRequests,
      unreadNotificationsCount,
      pendingReceivedInvitesCount,
    });
  }),
);
