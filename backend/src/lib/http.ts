import type { Response } from 'express';

export function sendJson<T>(res: Response, statusCode: number, payload: T): Response {
  return res.status(statusCode).json(payload);
}

export function sendOk<T>(res: Response, payload: T): Response {
  return sendJson(res, 200, payload);
}

export function sendCreated<T>(res: Response, payload: T): Response {
  return sendJson(res, 201, payload);
}

export function sendNoContent(res: Response): Response {
  return res.status(204).send();
}

export function sendError(
  res: Response,
  statusCode: number,
  message: string,
  options?: {
    code?: string;
    details?: unknown;
  },
): Response {
  return res.status(statusCode).json({
    error: {
      message,
      code: options?.code,
      details: options?.details,
    },
  });
}
