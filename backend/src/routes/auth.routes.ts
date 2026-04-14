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
