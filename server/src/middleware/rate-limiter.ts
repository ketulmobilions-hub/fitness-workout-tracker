import rateLimit, { type Options, type Store } from 'express-rate-limit';
import { RedisStore } from 'rate-limit-redis';
import { redis } from '../lib/redis.js';
import { env } from '../utils/env.js';

// Use Redis as the backing store so counters survive deploys and are shared
// across all server instances. Falls back to in-memory with a warning if Redis
// is not configured (e.g. local dev without REDIS_URL).
function makeStore(prefix: string): Store | undefined {
  if (!redis) {
    if (env.NODE_ENV === 'production') {
      console.warn(
        `[rate-limiter] REDIS_URL not set — using in-memory store for "${prefix}". Counters will reset on restart.`,
      );
    }
    return undefined; // express-rate-limit defaults to MemoryStore
  }

  const client = redis; // narrow to non-null for the closure
  return new RedisStore({
    prefix,
    sendCommand: async (...args: [string, ...string[]]): Promise<number> => {
      const [command, ...rest] = args;
      return client.call(command, ...rest) as Promise<number>;
    },
  });
}

const baseOptions = (store: Store | undefined): Partial<Options> => ({
  standardHeaders: true,
  legacyHeaders: false,
  store,
});

export const globalLimiter = rateLimit({
  ...baseOptions(makeStore('rl:global:')),
  windowMs: env.RATE_LIMIT_WINDOW_MS,
  max: env.RATE_LIMIT_MAX,
  message: {
    status: 429,
    error: 'Too Many Requests',
    message: 'Too many requests, please try again later.',
  },
});

export const authLimiter = rateLimit({
  ...baseOptions(makeStore('rl:auth:')),
  windowMs: env.RATE_LIMIT_WINDOW_MS,
  max: 20,
  message: {
    status: 429,
    error: 'Too Many Requests',
    message: 'Too many authentication attempts, please try again later.',
  },
});
