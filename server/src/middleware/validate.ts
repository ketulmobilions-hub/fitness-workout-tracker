import type { Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { AppError } from '../utils/errors.js';

interface ValidateSchemas {
  body?: z.ZodTypeAny;
  query?: z.ZodTypeAny;
  params?: z.ZodTypeAny;
}

export const validate =
  (schemas: ValidateSchemas) =>
  (req: Request, res: Response, next: NextFunction): void => {
    const sections = ['body', 'query', 'params'] as const;

    for (const section of sections) {
      const schema = schemas[section];
      if (!schema) continue;

      const result = schema.safeParse(req[section]);
      if (!result.success) {
        const details = result.error.issues.map((issue) => ({
          field: issue.path.join('.') || section,
          message: issue.message,
        }));
        next(new AppError(422, 'Validation failed', details));
        return;
      }

      // Store coerced/validated data on res.locals — req.query is a getter in Express 5
      // and cannot be reassigned. Controllers read from res.locals.validated.
      res.locals.validated ??= {};
      res.locals.validated[section] = result.data;
    }

    next();
  };
