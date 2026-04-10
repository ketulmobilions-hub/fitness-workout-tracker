import type { AuthLocals, ValidatedLocals } from './index.js';

// Augment Express.Locals so res.locals.validated and res.locals.auth are typed across the codebase.
declare global {
  namespace Express {
    interface Locals {
      validated?: ValidatedLocals;
      auth?: AuthLocals;
    }
  }
}
