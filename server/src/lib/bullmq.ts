import { ConnectionOptions } from 'bullmq';
import { env } from '../utils/env.js';

// BullMQ requires its own IORedis-compatible connection options.
// We derive them from REDIS_URL to reuse the same Redis instance as rate limiting.
export function getBullMQConnection(): ConnectionOptions {
  if (!env.REDIS_URL) {
    throw new Error('REDIS_URL is required for BullMQ job queues');
  }
  const url = new URL(env.REDIS_URL);
  return {
    host: url.hostname,
    port: Number(url.port) || 6379,
    password: url.password || undefined,
    username: url.username || undefined,
    // Explicit rejectUnauthorized to prevent silent cert-validation bypass on
    // managed Redis tiers (Render, ElastiCache) that use self-signed certs.
    tls: url.protocol === 'rediss:' ? { rejectUnauthorized: true } : undefined,
  };
}
