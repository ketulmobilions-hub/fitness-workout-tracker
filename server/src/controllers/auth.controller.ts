import type { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import crypto from 'node:crypto';
import { OAuth2Client } from 'google-auth-library';
import appleSignin from 'apple-signin-auth';
import { prisma } from '../lib/prisma.js';
import type { UserModel as User } from '../generated/prisma/models/User.js';
import { AppError } from '../utils/errors.js';
import { sendSuccess } from '../utils/response.js';
import { generateAccessToken, generateRefreshToken, verifyRefreshToken } from '../utils/jwt.js';
import { sendPasswordResetEmail } from '../utils/email.js';
import { env } from '../utils/env.js';

// Initialised once at module load — reuses the underlying JWKS cache across requests.
const googleClient = new OAuth2Client(env.GOOGLE_CLIENT_ID);

// Domain-separated hash — prevents a reset token hash from being accepted
// in the refresh token lookup or vice versa.
function hashToken(token: string, domain: 'refresh' | 'reset'): string {
  return crypto.createHash('sha256').update(`${domain}:${token}`).digest('hex');
}

// Used by register and login — generates and stores a new refresh token, then returns the
// raw token to the caller. Generating the token inside the transaction ensures the JWT `exp`
// and the DB `expiresAt` are both derived from the same PostgreSQL NOW() clock, eliminating
// divergence from app/DB clock skew at the 7-day expiry boundary.
// The refresh handler has its own inline version to include revocation in the same transaction.
async function storeRefreshToken(userId: string): Promise<string> {
  return prisma.$transaction(async (tx) => {
    // Lock the user row to serialize concurrent token creation for the same account.
    // Without this, two simultaneous logins both read the active-token count before either
    // commits (read-committed isolation), both pass the cap check, and both insert — allowing
    // the session limit to be exceeded. FOR UPDATE blocks the second transaction until the
    // first commits, so the second always sees the first's new token when counting.
    // Also fetches DB-server time so the JWT exp and DB expiresAt share the same clock.
    const rows = await tx.$queryRaw<Array<{ now: Date }>>`
      SELECT NOW() AS now FROM users WHERE id = ${userId}::uuid FOR UPDATE
    `;
    if (rows.length === 0) throw new AppError(401, 'User not found');
    const { now } = rows[0];
    const sevenDays = 7 * 24 * 60 * 60;
    const expiresAt = new Date(now.getTime() + sevenDays * 1000);
    // exp is a Unix timestamp (seconds). Passing it in the payload makes the JWT expiry
    // identical to the DB expiresAt — both derived from the same DB-server NOW().
    const exp = Math.floor(now.getTime() / 1000) + sevenDays;
    const rawToken = generateRefreshToken(userId, exp);

    // Remove stale tokens (revoked or expired)
    await tx.refreshToken.deleteMany({
      where: { userId, OR: [{ revokedAt: { not: null } }, { expiresAt: { lte: now } }] },
    });
    // Cap active sessions at 20 per user. Find the oldest tokens beyond the cap and delete them.
    // This prevents DB bloat from login loops or many devices accumulating rows indefinitely.
    const overflow = await tx.refreshToken.findMany({
      where: { userId, revokedAt: null, expiresAt: { gt: now } },
      orderBy: { createdAt: 'desc' },
      skip: 19, // keep 19 existing + 1 new = 20 total
      select: { id: true },
    });
    if (overflow.length > 0) {
      await tx.refreshToken.deleteMany({ where: { id: { in: overflow.map((t) => t.id) } } });
    }
    await tx.refreshToken.create({
      data: { userId, tokenHash: hashToken(rawToken, 'refresh'), expiresAt },
    });
    return rawToken;
  });
}

export const register = async (_req: Request, res: Response): Promise<void> => {
  const { email: rawEmail, password, displayName } = res.locals.validated!.body as {
    email: string;
    password: string;
    displayName?: string;
  };
  // Normalize email — prevents duplicate accounts via case variation (Alice@ vs alice@)
  const email = rawEmail.toLowerCase().trim();

  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) {
    throw new AppError(409, 'Email already in use');
  }

  const passwordHash = await bcrypt.hash(password, 12);

  let user: Awaited<ReturnType<typeof prisma.user.create>>;
  try {
    user = await prisma.user.create({
      data: { email, passwordHash, displayName: displayName ?? null, authProvider: 'email' },
    });
  } catch (err: unknown) {
    // Concurrent registration with the same email can race past the findUnique check above
    // and hit the DB unique constraint. Convert P2002 to 409 instead of surfacing as 500.
    if (err !== null && typeof err === 'object' && 'code' in err && err.code === 'P2002') {
      throw new AppError(409, 'Email already in use');
    }
    throw err;
  }

  // TypeScript narrowing — user.email is `string | null` on the Prisma model (guest accounts
  // have no email). In this path we just set email in the create call, so this is unreachable
  // in practice; it narrows the type so generateAccessToken receives `string`, not `string | null`.
  if (!user.email) throw new AppError(500, 'User account has no email address');

  const accessToken = generateAccessToken(user.id, user.email);
  const refreshToken = await storeRefreshToken(user.id);

  // NOTE: The refresh token is returned in the JSON body, which is safe for native
  // mobile clients (Flutter) storing it in platform secure storage. If a web client
  // is added in Phase 3, switch to httpOnly Secure SameSite=Strict cookies instead.
  sendSuccess(
    res,
    { user: { id: user.id, email: user.email, displayName: user.displayName }, accessToken, refreshToken },
    201,
  );
};

export const login = async (_req: Request, res: Response): Promise<void> => {
  const { email: rawEmail, password } = res.locals.validated!.body as { email: string; password: string };
  const email = rawEmail.toLowerCase().trim();

  const user = await prisma.user.findUnique({ where: { email } });
  // Same error for unknown email and wrong password — prevents user enumeration
  if (!user || !user.passwordHash) {
    throw new AppError(401, 'Invalid email or password');
  }

  const valid = await bcrypt.compare(password, user.passwordHash);
  if (!valid) {
    throw new AppError(401, 'Invalid email or password');
  }

  if (!user.email) throw new AppError(500, 'User account has no email address');

  const accessToken = generateAccessToken(user.id, user.email);
  const refreshToken = await storeRefreshToken(user.id);

  sendSuccess(res, {
    user: { id: user.id, email: user.email, displayName: user.displayName },
    accessToken,
    refreshToken,
  });
};

export const refresh = async (_req: Request, res: Response): Promise<void> => {
  const { refreshToken: rawToken } = res.locals.validated!.body as { refreshToken: string };

  // Verify JWT signature first — fast rejection without hitting the DB
  const payload = verifyRefreshToken(rawToken);

  // Single transaction: lock user + revoke old token + clean stale + cap sessions + create new.
  // Locking the user row (FOR UPDATE) serves two purposes:
  //   1. Serializes concurrent refreshes for the same account so the session cap cannot be
  //      bypassed by two requests both reading the active-token count before either commits.
  //   2. Fetches DB-server time (NOW()) so the new JWT exp and DB expiresAt share the same
  //      clock, preventing spurious logouts from app/DB clock skew at the 7-day boundary.
  // Fetching the user inside the transaction also ensures that if the user was deleted between
  // JWT issuance and now, the new token is never committed (tx rolls back on foundUser = null).
  // NOTE: The previous access token remains valid until it expires (≤15 min).
  // For stricter revocation, add a Redis-backed denylist keyed on the access token JTI.
  const result = await prisma.$transaction(async (tx) => {
    const rows = await tx.$queryRaw<Array<{ now: Date; id: string; email: string | null }>>`
      SELECT NOW() AS now, id, email FROM users WHERE id = ${payload.sub}::uuid FOR UPDATE
    `;
    if (rows.length === 0) throw new AppError(401, 'User not found');
    const { now, id, email } = rows[0];
    if (!email) throw new AppError(500, 'User account has no email address');
    const sevenDays = 7 * 24 * 60 * 60;
    const newExpiresAt = new Date(now.getTime() + sevenDays * 1000);
    const exp = Math.floor(now.getTime() / 1000) + sevenDays;
    // Generated inside the transaction so the JWT exp is derived from the same DB NOW()
    // as newExpiresAt — both clocks are identical, eliminating skew at the expiry boundary.
    const newRefreshToken = generateRefreshToken(payload.sub, exp);

    const revoked = await tx.refreshToken.updateMany({
      where: {
        tokenHash: hashToken(rawToken, 'refresh'),
        revokedAt: null,
        expiresAt: { gt: now },
      },
      data: { revokedAt: now },
    });
    if (revoked.count === 0) {
      throw new AppError(401, 'Refresh token expired or revoked');
    }
    // Cleanup removes stale tokens, but explicitly excludes the just-revoked token.
    // PostgreSQL makes a transaction's own writes visible to subsequent reads within the same
    // transaction, so without the exclusion the just-revoked row (revokedAt: now) would be
    // matched and deleted here, erasing the evidence of revocation. A concurrent replay of the
    // stolen token would then find 0 matching rows in the updateMany above (the row is gone)
    // and slip past the reuse-detection check. The excluded token stays revoked in the DB and
    // will be cleaned up on the next successful refresh.
    await tx.refreshToken.deleteMany({
      where: {
        userId: payload.sub,
        tokenHash: { not: hashToken(rawToken, 'refresh') },
        OR: [{ revokedAt: { not: null } }, { expiresAt: { lte: now } }],
      },
    });
    // Cap active sessions at 20 (same policy as storeRefreshToken used by register/login).
    const overflow = await tx.refreshToken.findMany({
      where: { userId: payload.sub, revokedAt: null, expiresAt: { gt: now } },
      orderBy: { createdAt: 'desc' },
      skip: 19,
      select: { id: true },
    });
    if (overflow.length > 0) {
      await tx.refreshToken.deleteMany({ where: { id: { in: overflow.map((t) => t.id) } } });
    }
    await tx.refreshToken.create({
      data: { userId: payload.sub, tokenHash: hashToken(newRefreshToken, 'refresh'), expiresAt: newExpiresAt },
    });
    return { id, email, newRefreshToken };
  });

  const newAccessToken = generateAccessToken(result.id, result.email);
  sendSuccess(res, { accessToken: newAccessToken, refreshToken: result.newRefreshToken });
};

export const forgotPassword = async (_req: Request, res: Response): Promise<void> => {
  const { email: rawEmail } = res.locals.validated!.body as { email: string };
  const email = rawEmail.toLowerCase().trim();
  const message = 'If that email is registered, a reset link has been sent. If you don\u2019t receive it within a few minutes, please try again.';

  const user = await prisma.user.findUnique({ where: { email } });
  if (!user) {
    // Always return success — never reveal whether an address is registered
    sendSuccess(res, { message });
    return;
  }

  const rawToken = crypto.randomBytes(32).toString('hex');

  // Atomic: delete ALL existing reset tokens for this user (used, expired, and active)
  // and create the new one in a single transaction. Deleting all tokens (not just active
  // ones) also prevents the table from accumulating stale rows indefinitely.
  // expiresAt is derived from PostgreSQL NOW() so the authoritative CAS in resetPassword
  // (which also uses SELECT NOW()) compares two values from the same clock — eliminating
  // the risk of clock skew between app and DB causing reset links to fail immediately.
  await prisma.$transaction(async (tx) => {
    const [{ now }] = await tx.$queryRaw<Array<{ now: Date }>>`SELECT NOW() AS now`;
    const expiresAt = new Date(now.getTime() + 60 * 60 * 1000); // 1 hour from DB time
    await tx.passwordResetToken.deleteMany({ where: { userId: user.id } });
    await tx.passwordResetToken.create({
      data: { userId: user.id, tokenHash: hashToken(rawToken, 'reset'), expiresAt },
    });
  });

  // encodeURIComponent is a no-op for hex tokens today but ensures safety if the
  // token encoding ever changes (e.g. base64url), and prevents URL/HTML injection.
  const resetUrl = `${env.APP_URL}/reset-password?token=${encodeURIComponent(rawToken)}`;
  try {
    await sendPasswordResetEmail(email, resetUrl);
  } catch (err) {
    // Log with userId (not email — PII) so the failure is traceable without leaking addresses.
    // TODO: replace console.error with Sentry.captureException (or equivalent) once
    // error monitoring is wired up — silent email failures are invisible in production.
    console.error(`[auth] Failed to send password reset email (userId: ${user.id}):`, err);
  }

  sendSuccess(res, { message });
};

// ─── Social Auth Helpers ─────────────────────────────────────────────────────

// Max length guard for provider sub identifiers (Issue #5).
// Google subs are 21-digit numeric strings; Apple subs are dot-separated identifiers.
// Both are well under 255 chars. A longer value indicates a malformed or tampered token.
const MAX_PROVIDER_USER_ID_LENGTH = 255;

// Returns the user to authenticate for a social login, following this lookup order:
//   1. Existing user with the same providerUserId  → return as-is (returning user, fast path)
//   2. Existing user with the same email           → link: attach providerUserId only
//   3. No match                                    → create a new user
//
// `email` may be null for Apple sign-ins after the first authorization — Apple only sends the
// email claim once. Subsequent logins must succeed via the providerUserId lookup alone.
//
// The entire lookup + link + create sequence runs inside a single serialized transaction
// (SELECT … FOR UPDATE on the email-matched user row) to prevent concurrent first-time
// sign-ins from racing and overwriting each other's providerUserId.
async function findOrCreateSocialUser(opts: {
  providerUserId: string;
  provider: 'google' | 'apple';
  email: string | null;
  displayName?: string;
}): Promise<User> {
  const { providerUserId, provider, email, displayName } = opts;

  // Issue #5: reject unexpectedly long sub values at the application layer before any DB write.
  if (providerUserId.length > MAX_PROVIDER_USER_ID_LENGTH) {
    throw new AppError(401, 'Invalid provider token');
  }

  // Fast path: returning social user — look up by the stable provider sub.
  // This path needs no transaction: providerUserId is already stored, no writes needed.
  const byProviderId = await prisma.user.findUnique({ where: { providerUserId } });
  if (byProviderId) return byProviderId;

  // Slow path: first-time sign-in. Wrap in a transaction with a FOR UPDATE lock on the
  // email-matched user (if any) to serialize concurrent first-time social sign-ins for
  // the same account — without this, two simultaneous requests can both pass the
  // providerUserId check above, both find the same email record, and race to update it,
  // with the second overwrite silently erasing the first's providerUserId. (Issue #4)
  return prisma.$transaction(async (tx) => {
    if (email) {
      // Lock the matched user row for the duration of this transaction so no concurrent
      // request can read or update it until we commit.
      const locked = await tx.$queryRaw<Array<{ id: string }>>`
        SELECT id FROM users WHERE email = ${email} FOR UPDATE
      `;

      if (locked.length > 0) {
        // Account linking: an existing user (any auth provider) is signing in via OAuth
        // for the first time. Attach providerUserId only — intentionally leave authProvider
        // unchanged so a password credential is not silently invalidated. (Issue #2)
        return tx.user.update({
          where: { id: locked[0].id },
          data: { providerUserId },
        });
      }
    }

    // New user — no matching record by sub or email.
    // P2002 on providerUserId: two concurrent first-time sign-ins with identical tokens
    // can race past the fast-path findUnique above (both read null before either commits).
    // The unique constraint ensures only one INSERT wins; the other gets P2002 and
    // re-fetches the now-committed row. (Race is serialized for the email path above via
    // FOR UPDATE; this handles the rarer same-token double-submit case for the create path.)
    try {
      return await tx.user.create({
        data: {
          email: email ?? null,
          authProvider: provider,
          providerUserId,
          displayName: displayName ?? null,
        },
      });
    } catch (err: unknown) {
      if (err !== null && typeof err === 'object' && 'code' in err && err.code === 'P2002') {
        const existing = await tx.user.findUnique({ where: { providerUserId } });
        if (existing) return existing;
      }
      throw err;
    }
  });
}

// ─── Social Auth Handlers ────────────────────────────────────────────────────

export const googleSignIn = async (_req: Request, res: Response): Promise<void> => {
  const { idToken } = res.locals.validated!.body as { idToken: string };

  let payload;
  try {
    const ticket = await googleClient.verifyIdToken({
      idToken,
      audience: env.GOOGLE_CLIENT_ID,
    });
    payload = ticket.getPayload();
  } catch {
    throw new AppError(401, 'Invalid Google ID token');
  }

  if (!payload?.sub) throw new AppError(401, 'Invalid Google ID token');

  // Issue #1: reject unverified emails before using them for account linking.
  // Google can return email_verified: false for older Workspace accounts or federated
  // identities. An attacker with an unverified email matching a victim's address would
  // otherwise be able to link their OAuth identity to the victim's account.
  // Apple does not expose an email_verified claim — Apple only issues email claims for
  // verified addresses, so no equivalent check is needed there.
  if (!payload.email_verified) {
    throw new AppError(401, 'Google account email is not verified');
  }

  const user = await findOrCreateSocialUser({
    providerUserId: payload.sub,
    provider: 'google',
    email: payload.email ?? null,
    displayName: payload.name,
  });

  // Google always provides a verified email — user.email is set at account creation or
  // inherited from the linked email account. Null here indicates data corruption.
  if (!user.email) throw new AppError(500, 'User account has no email address');

  const accessToken = generateAccessToken(user.id, user.email);
  const refreshToken = await storeRefreshToken(user.id);

  sendSuccess(res, {
    user: { id: user.id, email: user.email, displayName: user.displayName },
    accessToken,
    refreshToken,
  });
};

export const appleSignIn = async (_req: Request, res: Response): Promise<void> => {
  const { identityToken, displayName } = res.locals.validated!.body as {
    identityToken: string;
    displayName?: string;
  };

  let applePayload: Awaited<ReturnType<typeof appleSignin.verifyIdToken>>;
  try {
    applePayload = await appleSignin.verifyIdToken(identityToken, {
      audience: env.APPLE_APP_BUNDLE_ID,
      ignoreExpiration: false,
    });
  } catch {
    throw new AppError(401, 'Invalid Apple identity token');
  }

  if (!applePayload.sub) throw new AppError(401, 'Invalid Apple identity token');

  // Apple only sends the email claim on the very first authorization. Subsequent sign-ins
  // return a payload with no email — the lookup by providerUserId handles returning users.
  const email = applePayload.email ?? null;

  const user = await findOrCreateSocialUser({
    providerUserId: applePayload.sub,
    provider: 'apple',
    email,
    displayName,
  });

  // Issue #3: Apple users may legitimately have no email (not provided, or not shared).
  // Pass null directly — generateAccessToken now accepts string | null. Callers that need
  // an email (notifications, profile display) must handle the null case explicitly.
  const accessToken = generateAccessToken(user.id, user.email);
  const refreshToken = await storeRefreshToken(user.id);

  sendSuccess(res, {
    user: { id: user.id, email: user.email, displayName: user.displayName },
    accessToken,
    refreshToken,
  });
};

export const resetPassword = async (_req: Request, res: Response): Promise<void> => {
  const { token, newPassword } = res.locals.validated!.body as { token: string; newPassword: string };

  const tokenHash = hashToken(token, 'reset');

  // Validate existence and expiry before running bcrypt — avoids the ~200ms bcrypt cost
  // for tokens that are obviously invalid (not found, expired, or already used).
  // JS `new Date()` is used here as a fast-path optimisation only; the authoritative expiry
  // check is the `expiresAt: { gt: txNow }` CAS inside the transaction below, which uses
  // DB-server time to avoid app/DB clock skew.
  const jsNow = new Date();
  const resetToken = await prisma.passwordResetToken.findUnique({ where: { tokenHash } });
  if (!resetToken || resetToken.expiresAt < jsNow || resetToken.usedAt !== null) {
    throw new AppError(400, 'Reset token is invalid or has expired');
  }

  // bcrypt intentionally runs before the transaction. Running it inside the transaction would
  // hold a DB connection open for ~200ms (cost 12), increasing connection pressure under load.
  // The pre-check above already rejects invalid tokens cheaply; the CAS inside the transaction
  // is the authoritative guard against concurrent replays — any race that slips through the
  // pre-check is caught there and the hashed password is simply discarded.
  const passwordHash = await bcrypt.hash(newPassword, 12);

  // Atomic guard inside a transaction: the updateMany acts as a CAS on usedAt,
  // ensuring only one concurrent request can mark the token used. Any second
  // concurrent request gets count === 0 and is rejected before the password is updated.
  // txNow comes from the DB server to avoid app/DB clock skew at the expiry boundary.
  await prisma.$transaction(async (tx) => {
    const [{ now: txNow }] = await tx.$queryRaw<Array<{ now: Date }>>`SELECT NOW() AS now`;
    const marked = await tx.passwordResetToken.updateMany({
      where: { id: resetToken.id, usedAt: null, expiresAt: { gt: txNow } },
      data: { usedAt: txNow },
    });
    if (marked.count === 0) {
      throw new AppError(400, 'Reset token is invalid or has expired');
    }
    await tx.user.update({ where: { id: resetToken.userId }, data: { passwordHash } });
    // Revoke all active refresh tokens — forces re-login on all devices after a password reset
    await tx.refreshToken.updateMany({
      where: { userId: resetToken.userId, revokedAt: null },
      data: { revokedAt: txNow },
    });
  });

  sendSuccess(res, { message: 'Password has been reset. Please log in.' });
};
