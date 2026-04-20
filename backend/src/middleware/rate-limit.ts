import type { RequestHandler } from 'express';

import { HttpError } from '../lib/errors';

type RateLimitOptions = {
  windowMs: number;
  maxRequests: number;
  keyPrefix: string;
  keyGenerator?: (request: {
    ip: string;
    body: unknown;
    path: string;
  }) => string;
};

type RateLimitEntry = {
  timestamps: number[];
  lastSeenAt: number;
};

const rateLimitStore = new Map<string, RateLimitEntry>();

function normalizeIp(rawIp: string | undefined): string {
  const value = rawIp?.trim();
  return value && value.length > 0 ? value : 'unknown';
}

function pruneExpiredEntries(now: number, windowMs: number): void {
  for (const [key, entry] of rateLimitStore.entries()) {
    if (now - entry.lastSeenAt > windowMs * 2) {
      rateLimitStore.delete(key);
    }
  }
}

export function createRateLimitMiddleware(options: RateLimitOptions): RequestHandler {
  const {
    windowMs,
    maxRequests,
    keyPrefix,
    keyGenerator,
  } = options;

  return (req, _res, next) => {
    const now = Date.now();
    pruneExpiredEntries(now, windowMs);

    const ip = normalizeIp(req.ip);
    const scopedKey = keyGenerator == null
      ? `${keyPrefix}:${ip}`
      : `${keyPrefix}:${keyGenerator({
          ip,
          body: req.body,
          path: req.path,
        })}`;

    const existing = rateLimitStore.get(scopedKey);
    const freshTimestamps = (existing?.timestamps ?? []).filter(
      (timestamp) => now - timestamp < windowMs,
    );

    if (freshTimestamps.length >= maxRequests) {
      next(
        new HttpError(
          429,
          'Hai effettuato troppi tentativi. Attendi qualche minuto e riprova.',
        ),
      );
      return;
    }

    freshTimestamps.push(now);
    rateLimitStore.set(scopedKey, {
      timestamps: freshTimestamps,
      lastSeenAt: now,
    });

    next();
  };
}
