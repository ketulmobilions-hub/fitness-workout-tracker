import { afterAll } from 'vitest';
import { prisma, pool } from '../lib/prisma.js';

afterAll(async () => {
  await prisma.$disconnect();
  await pool.end();
});
