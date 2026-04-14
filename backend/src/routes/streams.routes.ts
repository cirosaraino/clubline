import { Router } from 'express';
import { z } from 'zod';

import { supabaseDb } from '../lib/supabase';
import { sendCreated, sendNoContent, sendOk } from '../lib/http';
import { realtimeEventsBus } from '../lib/realtime-events';
import { asyncHandler } from '../middleware/async-handler';
import { requireAuth } from '../middleware/auth';
import { StreamMetadataService } from '../services/stream-metadata.service';
import { StreamsService } from '../services/streams.service';

const streamInputSchema = z.object({
  stream_title: z.string().min(1),
  competition_name: z.string().nullable().optional(),
  played_on: z.string().min(1),
  stream_url: z.string().url(),
  stream_status: z.enum(['live', 'ended']),
  stream_ended_at: z.string().nullable().optional(),
  provider: z.string().nullable().optional(),
  result: z.string().nullable().optional(),
});

const streamMetadataSchema = z.object({
  url: z.string().url(),
});

export const streamsRouter = Router();
const streamsService = new StreamsService(supabaseDb);
const streamMetadataService = new StreamMetadataService(supabaseDb);

streamsRouter.get(
  '/',
  asyncHandler(async (_req, res) => {
    const streams = await streamsService.listStreams();
    sendOk(res, { streams });
  }),
);

streamsRouter.post(
  '/',
  requireAuth,
  asyncHandler(async (req, res) => {
    const stream = await streamsService.createStream(
      streamInputSchema.parse(req.body),
      req.principal!,
    );
    realtimeEventsBus.publishChange(['streams'], 'stream_created');
    sendCreated(res, { stream });
  }),
);

streamsRouter.post(
  '/metadata',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { url } = streamMetadataSchema.parse(req.body);
    const metadata = await streamMetadataService.fetchMetadata(url, req.principal!);
    sendOk(res, { metadata });
  }),
);

streamsRouter.delete(
  '/all',
  requireAuth,
  asyncHandler(async (req, res) => {
    await streamsService.deleteAllStreams(req.principal!);
    realtimeEventsBus.publishChange(['streams'], 'stream_deleted_all');
    sendNoContent(res);
  }),
);

streamsRouter.delete(
  '/day/:playedOn',
  requireAuth,
  asyncHandler(async (req, res) => {
    await streamsService.deleteStreamsForDay(req.params.playedOn, req.principal!);
    realtimeEventsBus.publishChange(['streams'], 'stream_deleted_day');
    sendNoContent(res);
  }),
);

streamsRouter.put(
  '/:id',
  requireAuth,
  asyncHandler(async (req, res) => {
    const stream = await streamsService.updateStream(
      req.params.id,
      streamInputSchema.parse(req.body),
      req.principal!,
    );
    realtimeEventsBus.publishChange(['streams'], 'stream_updated');
    sendOk(res, { stream });
  }),
);

streamsRouter.delete(
  '/:id',
  requireAuth,
  asyncHandler(async (req, res) => {
    await streamsService.deleteStream(req.params.id, req.principal!);
    realtimeEventsBus.publishChange(['streams'], 'stream_deleted');
    sendNoContent(res);
  }),
);
