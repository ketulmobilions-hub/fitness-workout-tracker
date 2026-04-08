import type { ValidatedLocals } from './index.js';

// Augment Express.Locals so res.locals.validated is typed across the codebase.
declare global {
  namespace Express {
    interface Locals {
      validated?: ValidatedLocals;
    }
  }
}
