import { Redis } from 'ioredis';
import { env } from '../utils/env.js';

let redisClient: Redis | null = null;

if (env.REDIS_URL) {
  redisClient = new Redis(env.REDIS_URL, {
    enableReadyCheck: true,
    maxRetriesPerRequest: 1,
    retryStrategy: (times: number): number | null => {
      if (times > 5) {
        console.error(`Redis: giving up after ${times} reconnection attempts`);
        return null;
      }
      return Math.min(times * 500, 5000);
    },
  });

  redisClient.on('error', (err: Error) => console.error('Redis error:', err.message));
  redisClient.on('connect', () => console.log('Redis connected'));
}

export const redis = redisClient;
