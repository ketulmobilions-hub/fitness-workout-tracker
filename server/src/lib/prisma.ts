import { PrismaClient } from '../generated/prisma/client.js';
import { PrismaPg } from '@prisma/adapter-pg';
import pg from 'pg';
import { env } from '../utils/env.js';

const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined;
  prismaPool: pg.Pool | undefined;
};

function createPrismaClient(): { client: PrismaClient; pool: pg.Pool } {
  const pool = new pg.Pool({
    connectionString: env.DATABASE_URL,
    max: 10,
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 5_000,
  });

  pool.on('error', (err) => {
    console.error('Unexpected pg pool error:', err);
  });

  const adapter = new PrismaPg(pool);
  const client = new PrismaClient({
    adapter,
    log: env.NODE_ENV === 'development' ? ['warn', 'error'] : ['error'],
  });
  return { client, pool };
}

const { client: prismaClient, pool: prismaPool } =
  globalForPrisma.prisma && globalForPrisma.prismaPool
    ? { client: globalForPrisma.prisma, pool: globalForPrisma.prismaPool }
    : createPrismaClient();

if (process.env.NODE_ENV !== 'production') {
  globalForPrisma.prisma = prismaClient;
  globalForPrisma.prismaPool = prismaPool;
}

export const prisma = prismaClient;
export const pool = prismaPool;
