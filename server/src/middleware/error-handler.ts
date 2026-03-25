import type { Request, Response, NextFunction } from 'express';
import type { ApiError } from '../types/index.js';

export const errorHandler = (
  err: ApiError | Error,
  _req: Request,
  res: Response,
  _next: NextFunction,
): void => {
  const status = 'status' in err ? err.status : 500;

  if (status >= 500) {
    console.error(`[ERROR] ${err.name}: ${err.message}`, err.stack);
  }

  const isApiError = 'status' in err;
  const message =
    status >= 500 && !isApiError ? 'An unexpected error occurred' : err.message || 'An unexpected error occurred';

  const response: Record<string, unknown> = {
    status,
    error: err.name || 'Internal Server Error',
    message,
  };

  if ('details' in err && err.details) {
    response.details = err.details;
  }

  res.status(status).json(response);
};
