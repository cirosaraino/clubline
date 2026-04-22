import { z } from 'zod';

export const credentialsSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6),
  redirectTo: z.string().url().optional(),
});

export const refreshSchema = z.object({
  refreshToken: z.string().min(1),
});

export const passwordResetRequestSchema = z.object({
  email: z.string().email(),
  redirectTo: z.string().url().optional(),
});

export const passwordUpdateSchema = z.object({
  password: z.string().min(6),
});
