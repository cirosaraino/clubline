import { z } from 'zod';

const positiveIntSchema = z.coerce.number().int().positive();

export const notificationsQuerySchema = z.object({
  filter: z.enum(['all', 'unread']).default('all'),
  limit: z.coerce.number().int().min(1).max(50).default(20),
  cursor: positiveIntSchema.optional(),
});

export const notificationIdParamSchema = z.object({
  id: positiveIntSchema,
});
