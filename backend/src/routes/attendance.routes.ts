import type { SupabaseClient } from '@supabase/supabase-js';
import type { RequestHandler } from 'express';
import { Router } from 'express';
import { z } from 'zod';

import { sendCreated, sendNoContent, sendOk } from '../lib/http';
import { publishRealtimeChange } from '../lib/realtime-publisher';
import { supabaseDb } from '../lib/supabase';
import { asyncHandler } from '../middleware/async-handler';
import { requireAuth } from '../middleware/auth';
import { AttendanceService } from '../services/attendance.service';
import { ClubNotificationPublisherService } from '../services/club-notification-publisher.service';

const createWeekSchema = z.object({
  reference_date: z.string().min(1),
  selected_dates: z.array(z.string().min(1)).min(1),
});

const saveAvailabilitySchema = z.object({
  week_id: z.union([z.string().min(1), z.number()]),
  player_id: z.union([z.string().min(1), z.number()]),
  attendance_date: z.string().min(1),
  availability: z.enum(['pending', 'yes', 'no']),
});

type AttendanceRouterOptions = {
  db?: SupabaseClient;
  authMiddleware?: RequestHandler;
  publishChange?: typeof publishRealtimeChange;
};

export function createAttendanceRouter(
  options: AttendanceRouterOptions = {},
): Router {
  const router = Router();
  const db = options.db ?? supabaseDb;
  const authMiddleware = options.authMiddleware ?? requireAuth;
  const publishChange = options.publishChange ?? publishRealtimeChange;
  const attendanceService = new AttendanceService(db);
  const notificationsPublisher = new ClubNotificationPublisherService(db);

  router.get(
    '/active-week',
    authMiddleware,
    asyncHandler(async (_req, res) => {
      const week = await attendanceService.getActiveWeek(_req.principal!);
      sendOk(res, { week });
    }),
  );

  router.post(
    '/weeks',
    authMiddleware,
    asyncHandler(async (req, res) => {
      const week = await attendanceService.createWeek(
        createWeekSchema.parse(req.body),
        req.principal!,
      );
      if (week) {
        await notificationsPublisher.publishAttendancePublished({
          clubId: week.club_id,
          clubName: req.principal?.club?.name,
          week,
        });
        publishChange(['attendance', 'lineups', 'notifications'], 'attendance_week_created');
      } else {
        publishChange(['attendance', 'lineups'], 'attendance_week_created');
      }
      sendCreated(res, { week });
    }),
  );

  router.post(
    '/weeks/:id/sync',
    authMiddleware,
    asyncHandler(async (req, res) => {
      await attendanceService.syncWeekEntriesForManager(req.params.id, req.principal!);
      sendNoContent(res);
    }),
  );

  router.post(
    '/weeks/:id/archive',
    authMiddleware,
    asyncHandler(async (req, res) => {
      await attendanceService.archiveWeek(req.params.id, req.principal!);
      publishChange(['attendance', 'lineups'], 'attendance_week_archived');
      sendNoContent(res);
    }),
  );

  router.post(
    '/weeks/:id/restore',
    authMiddleware,
    asyncHandler(async (req, res) => {
      await attendanceService.restoreArchivedWeek(req.params.id, req.principal!);
      publishChange(['attendance', 'lineups'], 'attendance_week_restored');
      sendNoContent(res);
    }),
  );

  router.delete(
    '/weeks/:id',
    authMiddleware,
    asyncHandler(async (req, res) => {
      await attendanceService.deleteArchivedWeek(req.params.id, req.principal!);
      publishChange(['attendance', 'lineups'], 'attendance_week_deleted');
      sendNoContent(res);
    }),
  );

  router.get(
    '/weeks/:id/entries',
    authMiddleware,
    asyncHandler(async (req, res) => {
      const entries = await attendanceService.listEntriesForWeek(req.params.id, req.principal!);
      sendOk(res, { entries });
    }),
  );

  router.get(
    '/archived-weeks',
    authMiddleware,
    asyncHandler(async (req, res) => {
      const excludingWeekId =
        typeof req.query.excluding_week_id === 'string'
          ? req.query.excluding_week_id
          : undefined;
      const limit = typeof req.query.limit === 'string'
        ? Number.parseInt(req.query.limit, 10)
        : undefined;

      const weeks = await attendanceService.listArchivedWeeks(req.principal!, {
        excludingWeekId,
        limit: Number.isFinite(limit) ? limit : undefined,
      });
      sendOk(res, { weeks });
    }),
  );

  router.put(
    '/entries',
    authMiddleware,
    asyncHandler(async (req, res) => {
      await attendanceService.saveAvailability(
        saveAvailabilitySchema.parse(req.body),
        req.principal!,
      );
      publishChange(['attendance', 'lineups'], 'attendance_updated');
      sendNoContent(res);
    }),
  );

  router.get(
    '/lineup-filters',
    authMiddleware,
    asyncHandler(async (req, res) => {
      const targetDate = typeof req.query.date === 'string' ? req.query.date : '';
      const filters = await attendanceService.getLineupFiltersForDate(targetDate, req.principal!);
      sendOk(res, { filters });
    }),
  );

  return router;
}

export const attendanceRouter = createAttendanceRouter();
