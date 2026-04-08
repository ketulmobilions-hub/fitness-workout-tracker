import type { Request, Response } from 'express';
import type { HealthResponse } from '../types/index.js';
import { prisma } from '../lib/prisma.js';
import { redis } from '../lib/redis.js';

export const getHealth = async (_req: Request, res: Response): Promise<void> => {
  const [dbStatus, redisStatus] = await Promise.all([
    prisma.$queryRaw`SELECT 1`
      .then(() => 'ok' as const)
      .catch((err: unknown) => {
        console.error('Health check: database error:', err);
        return 'error' as const;
      }),
    redis
      ? redis
          .ping()
          .then(() => 'ok' as const)
          .catch((err: unknown) => {
            console.error('Health check: redis error:', err);
            return 'error' as const;
          })
      : Promise.resolve('disconnected' as const),
  ]);

  // Healthy if DB is up AND Redis is either up or simply not configured.
  // Redis 'error' means REDIS_URL is set but the service is unreachable.
  const healthy = dbStatus === 'ok' && redisStatus !== 'error';

  const response: HealthResponse = {
    status: healthy ? 'ok' : 'degraded',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    services: { database: dbStatus, redis: redisStatus },
  };

  res.status(healthy ? 200 : 503).json(response);
};
