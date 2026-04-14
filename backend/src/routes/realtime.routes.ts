import type { Response } from 'express';
import { Router } from 'express';

import { realtimeEventsBus } from '../lib/realtime-events';

export const realtimeRouter = Router();

function sendSsePayload(res: Response, payload: unknown) {
  res.write(`data: ${JSON.stringify(payload)}\n\n`);
}

realtimeRouter.get('/events', (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache, no-transform');
  res.setHeader('Connection', 'keep-alive');
  res.setHeader('X-Accel-Buffering', 'no');
  res.flushHeaders();

  const requestedSince =
    typeof req.query.since === 'string' ? Number.parseInt(req.query.since, 10) : NaN;
  const sinceRevision = Number.isFinite(requestedSince) ? requestedSince : 0;

  const latestChange = realtimeEventsBus.getLatestChange();
  if (latestChange && latestChange.revision > sinceRevision) {
    sendSsePayload(res, latestChange);
  } else {
    sendSsePayload(res, {
      revision: sinceRevision,
      scopes: [],
      reason: 'connected',
      timestamp: new Date().toISOString(),
    });
  }

  const unsubscribe = realtimeEventsBus.subscribe((change) => {
    sendSsePayload(res, change);
  });

  const heartbeat = setInterval(() => {
    res.write(': heartbeat\n\n');
  }, 25000);

  req.on('close', () => {
    clearInterval(heartbeat);
    unsubscribe();
    res.end();
  });
});
