import rateLimit, { type Options, type Store } from 'express-rate-limit';
import { RedisStore } from 'rate-limit-redis';
import { redis } from '../lib/redis.js';
import { env } from '../utils/env.js';

// Use Redis as the backing store so counters survive deploys and are shared
// across all server instances. Falls back to in-memory in dev/test only.
// NOTE: makeStore is called at module-evaluation time (top-level rateLimit() calls below).
// The throw in the production path is guarded by env.ts superRefine, which rejects
// startup if REDIS_URL is absent in production — so the throw should never be reached
// in a correctly configured deployment.
function makeStore(prefix: string): Store | undefined {
  if (!redis) {
    if (env.NODE_ENV === 'production') {
      // Should not be reachable — env.ts requires REDIS_URL in production.
      // Throw anyway so a misconfigured deploy fails loudly at startup rather than
      // silently giving each instance its own counter.
      throw new Error(
        `[rate-limiter] REDIS_URL not set in production — in-memory fallback would give each instance its own counter, defeating rate limiting on multi-instance deployments`,
      );
    }
    return undefined; // express-rate-limit defaults to MemoryStore in dev/test
  }

  const client = redis; // narrow to non-null for the closure
  return new RedisStore({
    prefix,
    sendCommand: async (...args: [string, ...string[]]): Promise<number> => {
      const [command, ...rest] = args;
      return (await client.call(command, ...rest)) as number;
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

// For login and register: 10 attempts per window. 10 is generous for legitimate use
// (most users login ≤3 times per 15-min window) while meaningfully slowing credential stuffing.
export const authLimiter = rateLimit({
  ...baseOptions(makeStore('rl:auth:')),
  windowMs: env.RATE_LIMIT_WINDOW_MS,
  max: 10,
  message: {
    status: 429,
    error: 'Too Many Requests',
    message: 'Too many authentication attempts, please try again later.',
  },
});

// For token refresh: separate per-IP budget so a refresh storm on one device doesn't
// consume the global limit and lock out other routes. Higher than authLimiter because
// the app rotates tokens automatically (one per session per 15-min window normally).
export const refreshLimiter = rateLimit({
  ...baseOptions(makeStore('rl:refresh:')),
  windowMs: env.RATE_LIMIT_WINDOW_MS,
  max: 60,
  message: {
    status: 429,
    error: 'Too Many Requests',
    message: 'Too many refresh attempts, please try again later.',
  },
});

// For forgot-password: stricter limit to prevent email flooding
export const forgotPasswordLimiter = rateLimit({
  ...baseOptions(makeStore('rl:forgot:')),
  windowMs: env.RATE_LIMIT_WINDOW_MS,
  max: 5,
  message: {
    status: 429,
    error: 'Too Many Requests',
    message: 'Too many password reset attempts, please try again later.',
  },
});

// For reset-password: separate budget so junk reset attempts cannot exhaust the authLimiter
// counter and lock out /login from the same IP. Brute-forcing the 256-bit token is infeasible,
// so 10/window is purely to prevent abuse of the endpoint.
export const resetPasswordLimiter = rateLimit({
  ...baseOptions(makeStore('rl:reset:')),
  windowMs: env.RATE_LIMIT_WINDOW_MS,
  max: 10,
  message: {
    status: 429,
    error: 'Too Many Requests',
    message: 'Too many password reset attempts, please try again later.',
  },
});

// For guest account creation: stricter than authLimiter because there is no credential to
// deduplicate against — each call inserts a new user row. 3/window significantly reduces
// the surface for DB flooding via IP rotation while remaining invisible to real users (who
// create at most one guest session per 15-minute window).
export const guestLimiter = rateLimit({
  ...baseOptions(makeStore('rl:guest:')),
  windowMs: env.RATE_LIMIT_WINDOW_MS,
  max: 3,
  message: {
    status: 429,
    error: 'Too Many Requests',
    message: 'Too many guest account requests, please try again later.',
  },
});

// For guest-to-full-account upgrade: credential-sensitive (attaches email/OAuth),
// so the same budget as authLimiter is appropriate.
export const upgradeLimiter = rateLimit({
  ...baseOptions(makeStore('rl:upgrade:')),
  windowMs: env.RATE_LIMIT_WINDOW_MS,
  max: 10,
  message: {
    status: 429,
    error: 'Too Many Requests',
    message: 'Too many upgrade attempts, please try again later.',
  },
});
