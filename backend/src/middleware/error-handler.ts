import type { NextFunction, Request, Response } from 'express';
import { ZodError } from 'zod';

import { HttpError } from '../lib/errors';
import { sendError } from '../lib/http';

export function notFoundHandler(_req: Request, res: Response): void {
  sendError(res, 404, 'Endpoint non trovato');
}

export function errorHandler(
  error: unknown,
  _req: Request,
  res: Response,
  _next: NextFunction,
): void {
  if (error instanceof ZodError) {
    sendError(res, 400, error.issues.map((issue) => issue.message).join(', '));
    return;
  }

  if (error instanceof HttpError) {
    sendError(res, error.statusCode, error.message);
    return;
  }

  const maybeError = error as { code?: string; message?: string };
  if (maybeError.code === '23505') {
    sendError(res, 409, 'Record gia presente');
    return;
  }

  if (maybeError.code === '42501') {
    sendError(res, 403, 'Operazione non consentita');
    return;
  }

  sendError(res, 500, error instanceof Error ? error.message : 'Errore interno');
}
