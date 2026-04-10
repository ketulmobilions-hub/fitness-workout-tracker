import type { NextFunction, Request, Response } from 'express';
import { AppError } from '../utils/errors.js';

// Guards routes that guest accounts must not access. Apply after `authenticate` so
// res.locals.auth is already populated. Making this a dedicated middleware (rather than
// an inline `if` in each controller) ensures the policy is declarative and applied
// consistently — a developer cannot accidentally forget the guest check when wiring up
// a new protected route.
//
// Usage:
//   router.post('/workouts', authenticate, requireFullAccount, handler)
export const requireFullAccount = (_req: Request, res: Response, next: NextFunction): void => {
  if (res.locals.auth?.isGuest) {
    throw new AppError(403, 'Guest accounts cannot access this resource. Please upgrade your account first.');
  }
  next();
};
