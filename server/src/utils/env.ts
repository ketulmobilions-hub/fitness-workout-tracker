import 'dotenv/config';
import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  CORS_ORIGIN: z.string().optional(),
  DATABASE_URL: z.string().startsWith('postgresql://'),
  REDIS_URL: z.string().url().optional(),
});

export const env = envSchema.parse(process.env);
