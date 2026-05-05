import type { SupabaseClient } from '@supabase/supabase-js';
import type { RequestHandler } from 'express';
import { Router } from 'express';

import { sendOk } from '../lib/http';
import { publishRealtimeChange } from '../lib/realtime-publisher';
import { supabaseDb } from '../lib/supabase';
import { asyncHandler } from '../middleware/async-handler';
import { requireAuth } from '../middleware/auth';
import { NotificationsService } from '../services/notifications.service';
import {
  notificationIdParamSchema,
  notificationsQuerySchema,
} from '../validation/notifications.validation';

type NotificationsRouterOptions = {
  db?: SupabaseClient;
  authMiddleware?: RequestHandler;
  publishChange?: typeof publishRealtimeChange;
};

export function createNotificationsRouter(
  options: NotificationsRouterOptions = {},
): Router {
  const router = Router();
  const authMiddleware = options.authMiddleware ?? requireAuth;
  const publishChange = options.publishChange ?? publishRealtimeChange;
  const notificationsService = new NotificationsService(options.db ?? supabaseDb);

  router.get(
    '/',
    authMiddleware,
    asyncHandler(async (req, res) => {
      const result = await notificationsService.listNotifications(
        notificationsQuerySchema.parse(req.query),
        req.principal!,
      );
      sendOk(res, result);
    }),
  );

  router.post(
    '/read-all',
    authMiddleware,
    asyncHandler(async (req, res) => {
      const result = await notificationsService.markAllRead(req.principal!);
      publishChange(['notifications'], 'notifications_read_all');
      sendOk(res, {
        success: true,
        unreadCount: result.unreadCount,
      });
    }),
  );

  router.post(
    '/:id/read',
    authMiddleware,
    asyncHandler(async (req, res) => {
      const { id } = notificationIdParamSchema.parse(req.params);
      const result = await notificationsService.markRead(id, req.principal!);
      publishChange(['notifications'], 'notification_read');
      sendOk(res, {
        success: true,
        notification: result.notification,
        unreadCount: result.unreadCount,
      });
    }),
  );

  return router;
}

export const notificationsRouter = createNotificationsRouter();
