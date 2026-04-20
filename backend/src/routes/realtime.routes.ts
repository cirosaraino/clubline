import type { Response } from 'express';
import { Router } from 'express';

import { sendError } from '../lib/http';
import { realtimeTicketStore } from '../lib/realtime-ticket-store';
import { realtimeEventsBus } from '../lib/realtime-events';
import { requireAuth } from '../middleware/auth';

export const realtimeRouter = Router();

function sendSsePayload(res: Response, payload: unknown) {
  res.write(`data: ${JSON.stringify(payload)}\n\n`);
}

realtimeRouter.post('/session', requireAuth, async (req, res) => {
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
