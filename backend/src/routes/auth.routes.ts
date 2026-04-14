import { Router } from 'express';
import { z } from 'zod';

import { supabaseAuth, supabaseDb } from '../lib/supabase';
import { asyncHandler } from '../middleware/async-handler';
import { requireAuth } from '../middleware/auth';
import { sendCreated, sendOk } from '../lib/http';
import { AuthService } from '../services/auth.service';

const authService = new AuthService(supabaseAuth, supabaseDb);

const credentialsSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6),
});

const refreshSchema = z.object({
  refreshToken: z.string().min(1),
});

const passwordResetRequestSchema = z.object({
  email: z.string().email(),
  redirectTo: z.string().url().optional(),
});

const passwordUpdateSchema = z.object({
  password: z.string().min(6),
});

export const authRouter = Router();

authRouter.post(
  '/register',
  asyncHandler(async (req, res) => {
    const { email, password } = credentialsSchema.parse(req.body);
    const result = await authService.register(email, password);
    sendCreated(res, result);
  }),
);

authRouter.post(
  '/login',
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
      },
    });
  }),
);
