import bcrypt from 'bcryptjs';
import { prisma } from '../../lib/prisma.js';
import { generateAccessToken } from '../../utils/jwt.js';

export async function createTestUser(opts: {
  email?: string;
  password?: string;
  isGuest?: boolean;
} = {}): Promise<{ user: { id: string; authProvider: string; isGuest: boolean; email: string | null }, email: string | null, password: string | null }> {
  const email = opts.email ?? `test-${crypto.randomUUID()}@example.com`;
  const passwordHash = opts.password ? await bcrypt.hash(opts.password, 10) : null;

  const user = await prisma.user.create({
    data: {
      email: opts.isGuest ? null : email,
      passwordHash,
      authProvider: opts.isGuest ? 'guest' : 'email',
      isGuest: opts.isGuest ?? false,
    },
  });

  return { user, email: opts.isGuest ? null : email, password: opts.password ?? null };
}

export function getAuthHeader(userId: string, email: string | null, isGuest = false): string {
  const token = generateAccessToken(userId, email, isGuest);
  return `Bearer ${token}`;
}

export async function cleanupUser(userId: string): Promise<void> {
  await prisma.user.deleteMany({ where: { id: userId } });
}
