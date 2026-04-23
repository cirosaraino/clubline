export class HttpError extends Error {
  constructor(
    public readonly statusCode: number,
    message: string,
    public readonly code = 'http_error',
    public readonly details?: unknown,
  ) {
    super(message);
    this.name = 'HttpError';
  }
}

export class UnauthorizedError extends HttpError {
  constructor(
    message = 'Unauthorized',
    code = 'unauthorized',
    details?: unknown,
  ) {
    super(401, message, code, details);
    this.name = 'UnauthorizedError';
  }
}

export class ForbiddenError extends HttpError {
  constructor(
    message = 'Forbidden',
    code = 'forbidden',
    details?: unknown,
  ) {
    super(403, message, code, details);
    this.name = 'ForbiddenError';
  }
}

export class NotFoundError extends HttpError {
  constructor(
    message = 'Not found',
    code = 'not_found',
    details?: unknown,
  ) {
    super(404, message, code, details);
    this.name = 'NotFoundError';
  }
}

export class ConflictError extends HttpError {
  constructor(
    message = 'Conflict',
    code = 'conflict',
    details?: unknown,
  ) {
    super(409, message, code, details);
    this.name = 'ConflictError';
  }
}

export class ValidationError extends HttpError {
  constructor(
    message = 'Validation error',
    details?: unknown,
    code = 'validation_error',
  ) {
    super(400, message, code, details);
    this.name = 'ValidationError';
  }
}

export class TooManyRequestsError extends HttpError {
  constructor(
    message = 'Too many requests',
    code = 'too_many_requests',
    details?: unknown,
  ) {
    super(429, message, code, details);
    this.name = 'TooManyRequestsError';
  }
}

export class ServiceUnavailableError extends HttpError {
  constructor(
    message = 'Service unavailable',
    code = 'service_unavailable',
    details?: unknown,
  ) {
    super(503, message, code, details);
    this.name = 'ServiceUnavailableError';
  }
}
