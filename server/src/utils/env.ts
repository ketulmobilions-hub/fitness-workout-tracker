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
    JWT_SECRET: z.string().min(32),
    JWT_REFRESH_SECRET: z.string().min(32),
    APP_URL: z.string().url(),
    SMTP_HOST: z.string().optional(),
    SMTP_PORT: z.coerce.number().int().positive().default(587),
    SMTP_USER: z.string().optional(),
    SMTP_PASS: z.string().optional(),
    // Use 'example.invalid' (.invalid is an IANA-reserved TLD) to make misconfiguration
    // immediately obvious — emails from this default will be rejected by mail servers.
    SMTP_FROM: z.string().default('noreply@example.invalid'),
  })
  .superRefine((data, ctx) => {
    if (data.NODE_ENV === 'production' && !data.CORS_ORIGIN) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['CORS_ORIGIN'],
        message: 'CORS_ORIGIN is required in production',
      });
    }
    if (data.JWT_SECRET === data.JWT_REFRESH_SECRET) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['JWT_REFRESH_SECRET'],
        message: 'JWT_REFRESH_SECRET must be different from JWT_SECRET',
      });
    }
    if (data.NODE_ENV === 'production' && !data.REDIS_URL) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['REDIS_URL'],
        message: 'REDIS_URL is required in production for shared rate limiting across instances',
      });
    }
  });

export const env = envSchema.parse(process.env);
