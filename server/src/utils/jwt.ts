import jwt from 'jsonwebtoken';
import crypto from 'node:crypto';
import { env } from './env.js';
import { AppError } from './errors.js';

// `email` is `string | null` to accommodate Apple sign-in users who may have no email address
// (Apple only provides the email claim on first authorization). Callers that need an email
// address (e.g. notifications, profile display) must check for null before using this field.
export const generateAccessToken = (userId: string, email: string | null): string => {
  return jwt.sign({ sub: userId, email }, env.JWT_SECRET, { expiresIn: '15m' });
};

export const generateRefreshToken = (userId: string, exp?: number): string => {
  // jti (JWT ID) is a random UUID that guarantees uniqueness even when two tokens
  // are generated for the same user within the same second (identical iat otherwise).
  //
  // When `exp` is provided it must be a Unix timestamp (seconds since epoch).
  // Embedding it directly in the payload ensures the JWT expiry matches the DB `expiresAt`
  // column, which is computed from PostgreSQL NOW(). Without this, the JWT exp derives from
  // the Node.js clock and the DB expiry derives from the DB clock — clock skew between the
  // app container and PostgreSQL can cause one check to accept and the other to reject the
  // same token at the 7-day boundary, resulting in spurious logouts.
  if (exp !== undefined) {
    return jwt.sign({ sub: userId, jti: crypto.randomUUID(), exp }, env.JWT_REFRESH_SECRET);
  }
  return jwt.sign({ sub: userId, jti: crypto.randomUUID() }, env.JWT_REFRESH_SECRET, { expiresIn: '7d' });
};

export const verifyAccessToken = (token: string): { sub: string; email: string | null } => {
  try {
    const decoded = jwt.verify(token, env.JWT_SECRET);
    // Runtime guard — the `as` cast alone would silently pass tokens missing required fields.
    // `typeof decoded.sub !== 'string'` is explicit: the JWT spec allows any type for `sub`,
    // and a crafted token with a numeric sub would pass a falsy check while being invalid.
    // `email` is allowed to be null for Apple sign-in users who have no email address.
    const emailClaim = (decoded as Record<string, unknown>)['email'];
    if (
      typeof decoded === 'string' ||
      typeof decoded.sub !== 'string' ||
      !decoded.sub ||
      (emailClaim !== null && typeof emailClaim !== 'string')
    ) {
      throw new AppError(401, 'Invalid or expired access token');
    }
    return { sub: decoded.sub, email: emailClaim as string | null };
  } catch (err) {
    if (err instanceof AppError) throw err;
    throw new AppError(401, 'Invalid or expired access token');
  }
};

export const verifyRefreshToken = (token: string): { sub: string; jti: string } => {
  try {
    const decoded = jwt.verify(token, env.JWT_REFRESH_SECRET);
    // Runtime guard — also ensures jti is present, which is required by generateRefreshToken.
    // `typeof decoded.sub !== 'string'` is explicit for the same reason as verifyAccessToken.
    // NOTE: jti is in the return type for future denylist use (e.g. access token revocation
    // via Redis). It is NOT currently validated against a stored value in the DB — the DB
    // lookup uses the full token hash instead.
    if (
      typeof decoded === 'string' ||
      typeof decoded.sub !== 'string' ||
      !decoded.sub ||
      typeof decoded['jti'] !== 'string'
    ) {
      throw new AppError(401, 'Invalid or expired refresh token');
    }
    return { sub: decoded.sub, jti: decoded['jti'] as string };
  } catch (err) {
    if (err instanceof AppError) throw err;
    throw new AppError(401, 'Invalid or expired refresh token');
  }
};
