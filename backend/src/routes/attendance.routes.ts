import { Router } from 'express';
import { z } from 'zod';

import { supabaseDb } from '../lib/supabase';
import { sendCreated, sendNoContent, sendOk } from '../lib/http';
import { realtimeEventsBus } from '../lib/realtime-events';
import { asyncHandler } from '../middleware/async-handler';
import { requireAuth } from '../middleware/auth';
import { AttendanceService } from '../services/attendance.service';

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

export const attendanceRouter = Router();
const attendanceService = new AttendanceService(supabaseDb);

attendanceRouter.get(
  '/active-week',
  requireAuth,
  asyncHandler(async (_req, res) => {
    const week = await attendanceService.getActiveWeek();
    sendOk(res, { week });
  }),
);

attendanceRouter.post(
  '/weeks',
  requireAuth,
  asyncHandler(async (req, res) => {
    const week = await attendanceService.createWeek(
      createWeekSchema.parse(req.body),
      req.principal!,
    );
    realtimeEventsBus.publishChange(['attendance', 'lineups'], 'attendance_week_created');
    sendCreated(res, { week });
  }),
);

attendanceRouter.post(
  '/weeks/:id/sync',
  requireAuth,
  asyncHandler(async (req, res) => {
    await attendanceService.syncWeekEntries(req.params.id);
    sendNoContent(res);
  }),
);

attendanceRouter.post(
  '/weeks/:id/archive',
  requireAuth,
  asyncHandler(async (req, res) => {
    await attendanceService.archiveWeek(req.params.id, req.principal!);
    realtimeEventsBus.publishChange(['attendance', 'lineups'], 'attendance_week_archived');
    sendNoContent(res);
  }),
);

attendanceRouter.post(
  '/weeks/:id/restore',
  requireAuth,
  asyncHandler(async (req, res) => {
    await attendanceService.restoreArchivedWeek(req.params.id, req.principal!);
    realtimeEventsBus.publishChange(['attendance', 'lineups'], 'attendance_week_restored');
    sendNoContent(res);
  }),
);

attendanceRouter.delete(
  '/weeks/:id',
  requireAuth,
  asyncHandler(async (req, res) => {
    await attendanceService.deleteArchivedWeek(req.params.id, req.principal!);
    realtimeEventsBus.publishChange(['attendance', 'lineups'], 'attendance_week_deleted');
    sendNoContent(res);
  }),
);

attendanceRouter.get(
  '/weeks/:id/entries',
  requireAuth,
  asyncHandler(async (req, res) => {
    const entries = await attendanceService.listEntriesForWeek(req.params.id, req.principal!);
    sendOk(res, { entries });
  }),
);

attendanceRouter.get(
  '/archived-weeks',
  requireAuth,
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

attendanceRouter.put(
  '/entries',
  requireAuth,
  asyncHandler(async (req, res) => {
    await attendanceService.saveAvailability(
      saveAvailabilitySchema.parse(req.body),
      req.principal!,
    );
    realtimeEventsBus.publishChange(['attendance', 'lineups'], 'attendance_updated');
    sendNoContent(res);
  }),
);

attendanceRouter.get(
  '/lineup-filters',
  requireAuth,
  asyncHandler(async (req, res) => {
    const targetDate = typeof req.query.date === 'string' ? req.query.date : '';
    const filters = await attendanceService.getLineupFiltersForDate(targetDate, req.principal!);
    sendOk(res, { filters });
  }),
);
