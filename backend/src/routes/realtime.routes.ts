import type { Response } from 'express';
import { Router } from 'express';

import { env } from '../config/env';
import { sendError } from '../lib/http';
import { getLatestRealtimeChange, subscribeRealtimeChanges } from '../lib/realtime-publisher';
import { realtimeTicketStore } from '../lib/realtime-ticket-store';
import { requireAuth } from '../middleware/auth';

export const realtimeRouter = Router();

function sendSsePayload(res: Response, payload: unknown) {
  res.write(`data: ${JSON.stringify(payload)}\n\n`);
}

function ensureLocalRealtimeEnabled(res: Response): boolean {
  if (env.ENABLE_LOCAL_REALTIME_FALLBACK) {
    return true;
  }

  sendError(res, 410, 'Il canale realtime locale e disabilitato', {
    code: 'local_realtime_disabled',
    details: {
      preferred_mode: 'supabase_realtime',
    },
  });
  return false;
}

realtimeRouter.post('/session', requireAuth, async (req, res) => {
  if (!ensureLocalRealtimeEnabled(res)) {
    return;
  }

  const principal = req.principal;
  if (!principal) {
    sendError(res, 401, 'Sessione non valida');
    return;
  }

  const ticket = realtimeTicketStore.issue(principal.authUser.id);
  res.status(201).json({
    ticket: ticket.ticket,
    expiresAt: new Date(ticket.expiresAt).toISOString(),
  });
});

realtimeRouter.get('/events', async (req, res) => {
  if (!ensureLocalRealtimeEnabled(res)) {
    return;
  }

  const queryTicket =
    typeof req.query.ticket === 'string' ? req.query.ticket.trim() : '';
  if (!queryTicket) {
    sendError(res, 401, 'Ticket realtime mancante');
    return;
  }

  const ticket = realtimeTicketStore.validate(queryTicket);
  if (ticket == null) {
    sendError(res, 401, 'Sessione non valida');
    return;
  }

  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache, no-transform');
  res.setHeader('Connection', 'keep-alive');
  res.setHeader('X-Accel-Buffering', 'no');
  res.flushHeaders();

  const requestedSince =
    typeof req.query.since === 'string' ? Number.parseInt(req.query.since, 10) : NaN;
  const sinceRevision = Number.isFinite(requestedSince) ? requestedSince : 0;

  const latestChange = getLatestRealtimeChange();
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

  const unsubscribe = subscribeRealtimeChanges((change) => {
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
