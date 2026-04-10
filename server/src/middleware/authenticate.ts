import type { NextFunction, Request, Response } from 'express';
import { verifyAccessToken } from '../utils/jwt.js';
import { AppError } from '../utils/errors.js';

// Verifies the Bearer token in the Authorization header and writes the decoded claims to
// res.locals.auth. Throws 401 if the header is missing, malformed, or the token is invalid.
// Use on any route that requires an authenticated user (guest or full account).
export const authenticate = (_req: Request, res: Response, next: NextFunction): void => {
  const authHeader = _req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    throw new AppError(401, 'Missing or invalid Authorization header');
  }
  const token = authHeader.slice(7);
  const { sub, email, isGuest } = verifyAccessToken(token);
  res.locals.auth = { userId: sub, email, isGuest };
  next();
};
