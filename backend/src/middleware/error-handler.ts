import type { NextFunction, Request, Response } from 'express';
import { ZodError } from 'zod';

import { env } from '../config/env';
import { HttpError, ValidationError } from '../lib/errors';
import { sendError } from '../lib/http';

export function notFoundHandler(_req: Request, res: Response): void {
  sendError(res, 404, 'Endpoint non trovato', {
    code: 'endpoint_not_found',
  });
}

export function errorHandler(
  error: unknown,
  _req: Request,
  res: Response,
  _next: NextFunction,
): void {
  if (error instanceof ZodError) {
    const validationError = new ValidationError(
      error.issues.map((issue) => issue.message).join(', '),
      error.issues.map((issue) => ({
        path: issue.path.join('.'),
        message: issue.message,
        code: issue.code,
      })),
    );

    sendError(res, validationError.statusCode, validationError.message, {
      code: validationError.code,
      details: validationError.details,
    });
    return;
  }

  if (error instanceof HttpError) {
    sendError(res, error.statusCode, error.message, {
      code: error.code,
      details: error.details,
    });
    return;
  }

  const maybeError = error as { code?: string; message?: string };
  if (maybeError.code === '23505') {
    sendError(res, 409, 'Record gia presente', {
      code: 'unique_constraint_violation',
    });
    return;
  }

  if (maybeError.code === '42501') {
    sendError(res, 403, 'Operazione non consentita', {
      code: 'db_permission_denied',
    });
    return;
  }

  console.error(error);

  sendError(
    res,
    500,
    env.NODE_ENV == 'production'
      ? 'Errore interno'
      : error instanceof Error
          ? error.message
          : 'Errore interno',
    {
      code: 'internal_error',
    },
  );
}
