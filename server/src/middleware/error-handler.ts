import type { Request, Response, NextFunction } from 'express';
import { AppError } from '../utils/errors.js';
import { env } from '../utils/env.js';

const HTTP_STATUS_TEXT: Record<number, string> = {
  400: 'Bad Request',
  401: 'Unauthorized',
  403: 'Forbidden',
  404: 'Not Found',
  409: 'Conflict',
  422: 'Unprocessable Entity',
  429: 'Too Many Requests',
  500: 'Internal Server Error',
  503: 'Service Unavailable',
};

export const errorHandler = (
  err: AppError | Error,
  _req: Request,
  res: Response,
  _next: NextFunction,
): void => {
  const status = err instanceof AppError ? err.status : 500;
  const errorText = HTTP_STATUS_TEXT[status] ?? 'Internal Server Error';

  if (status >= 500) {
    console.error(`[ERROR] ${err.message}`, err.stack);
  }

  // Redact all 5xx messages in production — only 4xx AppErrors are safe to surface to clients.
  const isClientError = err instanceof AppError && status < 500;
  const message =
    !isClientError && env.NODE_ENV === 'production'
      ? 'An unexpected error occurred'
      : err.message || 'An unexpected error occurred';

  const response: Record<string, unknown> = { status, error: errorText, message };

  if (err instanceof AppError && err.details) {
    response.details = err.details;
  }

  res.status(status).json(response);
};
