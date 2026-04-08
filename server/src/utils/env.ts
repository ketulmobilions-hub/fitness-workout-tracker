import 'dotenv/config';
import { z } from 'zod';

const envSchema = z
  .object({
    NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
    PORT: z.coerce.number().int().min(1).max(65535).default(3000),
    CORS_ORIGIN: z.string().optional(),
    DATABASE_URL: z.string().refine(
      (v) => v.startsWith('postgresql://') || v.startsWith('postgres://'),
      { message: 'Must be a valid PostgreSQL connection string (postgresql:// or postgres://)' },
    ),
    REDIS_URL: z.string().url().optional(),
    RATE_LIMIT_WINDOW_MS: z.coerce.number().int().positive().default(15 * 60 * 1000),
    RATE_LIMIT_MAX: z.coerce.number().int().positive().default(200),
  })
  .superRefine((data, ctx) => {
    if (data.NODE_ENV === 'production' && !data.CORS_ORIGIN) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['CORS_ORIGIN'],
        message: 'CORS_ORIGIN is required in production',
      });
    }
  });

export const env = envSchema.parse(process.env);
