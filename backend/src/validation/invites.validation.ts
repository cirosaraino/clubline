import { z } from 'zod';

const positiveIntSchema = z.coerce.number().int().positive();

export const inviteCandidatesQuerySchema = z.object({
  q: z.string().trim().min(1).max(80),
  limit: z.coerce.number().int().min(1).max(20).default(20),
});

export const createInviteSchema = z.object({
  targetUserId: z.string().uuid(),
});

export const inviteListQuerySchema = z.object({
  status: z.enum(['pending', 'all']).default('pending'),
  limit: z.coerce.number().int().min(1).max(50).default(20),
  cursor: positiveIntSchema.optional(),
});

export const inviteIdParamSchema = z.object({
  id: positiveIntSchema,
});
