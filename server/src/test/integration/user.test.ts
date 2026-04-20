import { describe, it, expect, beforeAll, afterAll, vi } from 'vitest';
import request from 'supertest';
import app from '../../app.js';
import { prisma } from '../../lib/prisma.js';
import { createTestUser, getAuthHeader, cleanupUser } from '../helpers/auth.js';

// Mock OAuth libraries — hoisted by vitest before any imports so the module-level
// OAuth2Client instance in user.controller.ts receives the mock.
vi.mock('google-auth-library', () => ({
  OAuth2Client: class {
    verifyIdToken({ idToken }: { idToken: string }): Promise<unknown> {
      if (idToken === 'valid-google-token') {
        return Promise.resolve({
          getPayload: () => ({ sub: 'google-sub-123', email: 'google@example.com', email_verified: true }),
        });
      }
      return Promise.reject(new Error('Token verification failed'));
    }
  },
}));

vi.mock('apple-signin-auth', () => ({
  default: {
    verifyIdToken: vi.fn().mockImplementation((token: string) => {
      if (token === 'valid-apple-token') {
        return Promise.resolve({ sub: 'apple-sub-123', email: 'apple@example.com' });
      }
      return Promise.reject(new Error('Token verification failed'));
    }),
  },
}));

// ─── GET /api/v1/users/me ────────────────────────────────────────────────────

describe('GET /api/v1/users/me', () => {
  let userId: string;
  let authHeader: string;

  beforeAll(async () => {
    const { user, email } = await createTestUser({ password: 'test1234' });
    userId = user.id;
    authHeader = getAuthHeader(user.id, email);
  });

  afterAll(async () => {
    await cleanupUser(userId);
  });

  it('returns 200 with correct profile shape', async () => {
    const res = await request(app).get('/api/v1/users/me').set('Authorization', authHeader);

    expect(res.status).toBe(200);
    expect(res.body.data.user).toMatchObject({
      id: userId,
      isGuest: false,
      authProvider: 'email',
      preferences: {},
    });
    expect(res.body.data.user).toHaveProperty('displayName');
    expect(res.body.data.user).toHaveProperty('avatarUrl');
    expect(res.body.data.user).toHaveProperty('bio');
    expect(res.body.data.user).toHaveProperty('createdAt');
    expect(res.body.data.user).toHaveProperty('updatedAt');
    expect(res.body.data.user).not.toHaveProperty('passwordHash');
  });

  it('returns 200 for guest user', async () => {
    const { user } = await createTestUser({ isGuest: true });
    const header = getAuthHeader(user.id, null, true);

    try {
      const res = await request(app).get('/api/v1/users/me').set('Authorization', header);
      expect(res.status).toBe(200);
      expect(res.body.data.user.isGuest).toBe(true);
    } finally {
      await cleanupUser(user.id);
    }
  });

  it('returns 401 without auth token', async () => {
    const res = await request(app).get('/api/v1/users/me');
    expect(res.status).toBe(401);
  });
});

// ─── PATCH /api/v1/users/me ──────────────────────────────────────────────────

describe('PATCH /api/v1/users/me', () => {
  let userId: string;
  let email: string | null;
  let authHeader: string;

  beforeAll(async () => {
    const result = await createTestUser({ password: 'test1234' });
    userId = result.user.id;
    email = result.email;
    authHeader = getAuthHeader(userId, email);
  });

  afterAll(async () => {
    await cleanupUser(userId);
  });

  it('updates displayName successfully', async () => {
    const res = await request(app)
      .patch('/api/v1/users/me')
      .set('Authorization', authHeader)
      .send({ displayName: 'Test User' });

    expect(res.status).toBe(200);
    expect(res.body.data.user.displayName).toBe('Test User');
  });

  it('updates bio successfully', async () => {
    const res = await request(app)
      .patch('/api/v1/users/me')
      .set('Authorization', authHeader)
      .send({ bio: 'Fitness enthusiast.' });

    expect(res.status).toBe(200);
    expect(res.body.data.user.bio).toBe('Fitness enthusiast.');
  });

  it('clears avatarUrl when sent as null', async () => {
    await prisma.user.update({ where: { id: userId }, data: { avatarUrl: 'https://example.com/avatar.jpg' } });

    const res = await request(app)
      .patch('/api/v1/users/me')
      .set('Authorization', authHeader)
      .send({ avatarUrl: null });

    expect(res.status).toBe(200);
    expect(res.body.data.user.avatarUrl).toBeNull();
  });

  it('returns 422 when avatarUrl uses http://', async () => {
    const res = await request(app)
      .patch('/api/v1/users/me')
      .set('Authorization', authHeader)
      .send({ avatarUrl: 'http://example.com/avatar.jpg' });

    expect(res.status).toBe(422);
  });

  it('returns 422 when no fields are provided', async () => {
    const res = await request(app)
      .patch('/api/v1/users/me')
      .set('Authorization', authHeader)
      .send({});

    expect(res.status).toBe(422);
  });

  it('returns 422 when avatarUrl is not a valid URL', async () => {
    const res = await request(app)
      .patch('/api/v1/users/me')
      .set('Authorization', authHeader)
      .send({ avatarUrl: 'not-a-url' });

    expect(res.status).toBe(422);
  });

  it('returns 422 when bio exceeds 500 characters', async () => {
    const res = await request(app)
      .patch('/api/v1/users/me')
      .set('Authorization', authHeader)
      .send({ bio: 'x'.repeat(501) });

    expect(res.status).toBe(422);
  });

  it('returns 403 for guest accounts', async () => {
    const { user } = await createTestUser({ isGuest: true });
    const header = getAuthHeader(user.id, null, true);

    try {
      const res = await request(app)
        .patch('/api/v1/users/me')
        .set('Authorization', header)
        .send({ displayName: 'Ghost' });
      expect(res.status).toBe(403);
    } finally {
      await cleanupUser(user.id);
    }
  });

  it('returns 401 without auth token', async () => {
    const res = await request(app).patch('/api/v1/users/me').send({ displayName: 'Nobody' });
    expect(res.status).toBe(401);
  });
});

// ─── PATCH /api/v1/users/me/preferences ─────────────────────────────────────

describe('PATCH /api/v1/users/me/preferences', () => {
  let userId: string;
  let email: string | null;
  let authHeader: string;

  beforeAll(async () => {
    const result = await createTestUser({ password: 'test1234' });
    userId = result.user.id;
    email = result.email;
    authHeader = getAuthHeader(userId, email);
  });

  afterAll(async () => {
    await cleanupUser(userId);
  });

  it('saves preferences and returns them', async () => {
    const res = await request(app)
      .patch('/api/v1/users/me/preferences')
      .set('Authorization', authHeader)
      .send({ units: 'metric', theme: 'dark' });

    expect(res.status).toBe(200);
    expect(res.body.data.preferences).toMatchObject({ units: 'metric', theme: 'dark' });
  });

  it('merges preferences without wiping unrelated fields', async () => {
    await request(app)
      .patch('/api/v1/users/me/preferences')
      .set('Authorization', authHeader)
      .send({ units: 'imperial' });

    const res = await request(app)
      .patch('/api/v1/users/me/preferences')
      .set('Authorization', authHeader)
      .send({ theme: 'light' });

    expect(res.status).toBe(200);
    expect(res.body.data.preferences).toMatchObject({ units: 'imperial', theme: 'light' });
  });

  it('returns 422 when no preference fields provided', async () => {
    const res = await request(app)
      .patch('/api/v1/users/me/preferences')
      .set('Authorization', authHeader)
      .send({});

    expect(res.status).toBe(422);
  });

  it('returns 403 for guest accounts', async () => {
    const { user } = await createTestUser({ isGuest: true });
    const header = getAuthHeader(user.id, null, true);

    try {
      const res = await request(app)
        .patch('/api/v1/users/me/preferences')
        .set('Authorization', header)
        .send({ theme: 'dark' });
      expect(res.status).toBe(403);
    } finally {
      await cleanupUser(user.id);
    }
  });
});

// ─── GET /api/v1/users/me/stats ─────────────────────────────────────────────

describe('GET /api/v1/users/me/stats', () => {
  let userId: string;
  let email: string | null;
  let authHeader: string;

  beforeAll(async () => {
    const result = await createTestUser({ password: 'test1234' });
    userId = result.user.id;
    email = result.email;
    authHeader = getAuthHeader(userId, email);
  });

  afterAll(async () => {
    await cleanupUser(userId);
  });

  it('returns 200 with all stats fields for a new user', async () => {
    const res = await request(app).get('/api/v1/users/me/stats').set('Authorization', authHeader);

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({
      totalWorkouts: 0,
      totalVolumeKg: 0,
      currentStreak: 0,
      longestStreak: 0,
    });
    expect(res.body.data).toHaveProperty('memberSince');
    expect(res.body.data).toHaveProperty('lastWorkoutDate');
  });

  it('counts only completed sessions, not in_progress', async () => {
    // Baseline: 0 workouts before creating any sessions
    const baseline = await request(app).get('/api/v1/users/me/stats').set('Authorization', authHeader);
    expect(baseline.body.data.totalWorkouts).toBe(0);

    // Create one completed and one in_progress session
    await prisma.workoutSession.createMany({
      data: [
        { userId, startedAt: new Date(), status: 'completed', completedAt: new Date() },
        { userId, startedAt: new Date(), status: 'in_progress' },
      ],
    });

    const res = await request(app).get('/api/v1/users/me/stats').set('Authorization', authHeader);

    expect(res.status).toBe(200);
    // Exactly 1 — the in_progress session must NOT be counted (not 2)
    expect(res.body.data.totalWorkouts).toBe(1);
  });

  it('returns 200 for guest users', async () => {
    const { user } = await createTestUser({ isGuest: true });
    const header = getAuthHeader(user.id, null, true);

    try {
      const res = await request(app).get('/api/v1/users/me/stats').set('Authorization', header);
      expect(res.status).toBe(200);
    } finally {
      await cleanupUser(user.id);
    }
  });

  it('returns 401 without auth token', async () => {
    const res = await request(app).get('/api/v1/users/me/stats');
    expect(res.status).toBe(401);
  });
});

// ─── DELETE /api/v1/users/me ─────────────────────────────────────────────────

describe('DELETE /api/v1/users/me', () => {
  it('deletes email account with correct password and confirmPhrase', async () => {
    const password = 'correctpassword';
    const { user, email } = await createTestUser({ password });
    const authHeader = getAuthHeader(user.id, email);

    const res = await request(app)
      .delete('/api/v1/users/me')
      .set('Authorization', authHeader)
      .send({ password, confirmPhrase: 'DELETE MY ACCOUNT' });

    expect(res.status).toBe(200);
    expect(res.body.data.message).toBe('Account deleted successfully');

    const deleted = await prisma.user.findUnique({ where: { id: user.id } });
    expect(deleted).toBeNull();
  });

  it('returns 401 for wrong password', async () => {
    const { user, email } = await createTestUser({ password: 'realpassword' });
    const authHeader = getAuthHeader(user.id, email);

    try {
      const res = await request(app)
        .delete('/api/v1/users/me')
        .set('Authorization', authHeader)
        .send({ password: 'wrongpassword', confirmPhrase: 'DELETE MY ACCOUNT' });
      expect(res.status).toBe(401);
    } finally {
      await cleanupUser(user.id);
    }
  });

  it('returns 400 when password is missing for email account', async () => {
    const { user, email } = await createTestUser({ password: 'somepassword' });
    const authHeader = getAuthHeader(user.id, email);

    try {
      const res = await request(app)
        .delete('/api/v1/users/me')
        .set('Authorization', authHeader)
        .send({ confirmPhrase: 'DELETE MY ACCOUNT' });
      expect(res.status).toBe(400);
    } finally {
      await cleanupUser(user.id);
    }
  });

  it('returns 422 when confirmPhrase is wrong', async () => {
    const { user, email } = await createTestUser({ password: 'somepassword' });
    const authHeader = getAuthHeader(user.id, email);

    try {
      const res = await request(app)
        .delete('/api/v1/users/me')
        .set('Authorization', authHeader)
        .send({ password: 'somepassword', confirmPhrase: 'delete my account' });
      expect(res.status).toBe(422);
    } finally {
      await cleanupUser(user.id);
    }
  });

  it('returns 422 when confirmPhrase is missing', async () => {
    const { user, email } = await createTestUser({ password: 'somepassword' });
    const authHeader = getAuthHeader(user.id, email);

    try {
      const res = await request(app)
        .delete('/api/v1/users/me')
        .set('Authorization', authHeader)
        .send({ password: 'somepassword' });
      expect(res.status).toBe(422);
    } finally {
      await cleanupUser(user.id);
    }
  });

  it('returns 403 for guest accounts', async () => {
    const { user } = await createTestUser({ isGuest: true });
    const header = getAuthHeader(user.id, null, true);

    try {
      const res = await request(app)
        .delete('/api/v1/users/me')
        .set('Authorization', header)
        .send({ confirmPhrase: 'DELETE MY ACCOUNT' });
      expect(res.status).toBe(403);
    } finally {
      await cleanupUser(user.id);
    }
  });

  // ── OAuth deletion (Issue 1 fix) ─────────────────────────────────────────

  it('returns 400 when Google user omits idToken', async () => {
    const { user } = await createTestUser({ isGuest: false });
    await prisma.user.update({ where: { id: user.id }, data: { authProvider: 'google', passwordHash: null } });
    const authHeader = getAuthHeader(user.id, 'google@example.com');

    try {
      const res = await request(app)
        .delete('/api/v1/users/me')
        .set('Authorization', authHeader)
        .send({ confirmPhrase: 'DELETE MY ACCOUNT' });
      expect(res.status).toBe(400);
    } finally {
      await cleanupUser(user.id);
    }
  });

  it('returns 401 when Google user provides an invalid idToken', async () => {
    const { user } = await createTestUser({ isGuest: false });
    await prisma.user.update({ where: { id: user.id }, data: { authProvider: 'google', passwordHash: null } });
    const authHeader = getAuthHeader(user.id, 'google@example.com');

    try {
      const res = await request(app)
        .delete('/api/v1/users/me')
        .set('Authorization', authHeader)
        .send({ idToken: 'bad-token', confirmPhrase: 'DELETE MY ACCOUNT' });
      expect(res.status).toBe(401);
    } finally {
      await cleanupUser(user.id);
    }
  });

  it('deletes Google account with valid idToken', async () => {
    const { user } = await createTestUser({ isGuest: false });
    await prisma.user.update({ where: { id: user.id }, data: { authProvider: 'google', passwordHash: null } });
    const authHeader = getAuthHeader(user.id, 'google@example.com');

    const res = await request(app)
      .delete('/api/v1/users/me')
      .set('Authorization', authHeader)
      .send({ idToken: 'valid-google-token', confirmPhrase: 'DELETE MY ACCOUNT' });

    expect(res.status).toBe(200);

    const deleted = await prisma.user.findUnique({ where: { id: user.id } });
    expect(deleted).toBeNull();
  });

  it('returns 400 when Apple user omits identityToken', async () => {
    const { user } = await createTestUser({ isGuest: false });
    await prisma.user.update({ where: { id: user.id }, data: { authProvider: 'apple', passwordHash: null } });
    const authHeader = getAuthHeader(user.id, null);

    try {
      const res = await request(app)
        .delete('/api/v1/users/me')
        .set('Authorization', authHeader)
        .send({ confirmPhrase: 'DELETE MY ACCOUNT' });
      expect(res.status).toBe(400);
    } finally {
      await cleanupUser(user.id);
    }
  });

  it('deletes Apple account with valid identityToken', async () => {
    const { user } = await createTestUser({ isGuest: false });
    await prisma.user.update({ where: { id: user.id }, data: { authProvider: 'apple', passwordHash: null } });
    const authHeader = getAuthHeader(user.id, null);

    const res = await request(app)
      .delete('/api/v1/users/me')
      .set('Authorization', authHeader)
      .send({ identityToken: 'valid-apple-token', confirmPhrase: 'DELETE MY ACCOUNT' });

    expect(res.status).toBe(200);

    const deleted = await prisma.user.findUnique({ where: { id: user.id } });
    expect(deleted).toBeNull();
  });
});
