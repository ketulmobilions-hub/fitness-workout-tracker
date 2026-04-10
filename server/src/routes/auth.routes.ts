import { Router } from 'express';
import { z } from 'zod';
import { authLimiter, forgotPasswordLimiter, guestLimiter, refreshLimiter, resetPasswordLimiter, upgradeLimiter } from '../middleware/rate-limiter.js';
import { validate } from '../middleware/validate.js';
import { authenticate } from '../middleware/authenticate.js';
import * as auth from '../controllers/auth.controller.js';

const router = Router();

const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8).max(128),
  displayName: z.string().min(1).max(50).optional(),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

const refreshSchema = z.object({
  refreshToken: z.string().min(1),
});

const forgotPasswordSchema = z.object({
  email: z.string().email(),
});

const resetPasswordSchema = z.object({
  token: z.string().min(1),
  newPassword: z.string().min(8).max(128),
});

const googleSchema = z.object({
  idToken: z.string().min(1),
});

const appleSchema = z.object({
  identityToken: z.string().min(1),
  displayName: z.string().min(1).max(50).optional(),
});

// Discriminated union so validation error messages name the exact failing field per upgrade type.
const upgradeSchema = z.discriminatedUnion('type', [
  z.object({
    type: z.literal('email'),
    email: z.string().email(),
    password: z.string().min(8).max(128),
    displayName: z.string().min(1).max(50).optional(),
  }),
  z.object({
    type: z.literal('google'),
    idToken: z.string().min(1),
  }),
  z.object({
    type: z.literal('apple'),
    identityToken: z.string().min(1),
    displayName: z.string().min(1).max(50).optional(),
  }),
]);

// authLimiter (10/window)       — login, register: credential-sensitive
// refreshLimiter (60/window)    — token rotation: separate budget so a refresh storm on one
//                                  device doesn't exhaust the auth limit and block other routes
// forgotPasswordLimiter (5/window) — prevent email flooding
// resetPasswordLimiter (10/window) — separate from authLimiter so junk reset attempts can't
//                                    exhaust the login budget and lock out /login from the same IP
router.post('/register', authLimiter, validate({ body: registerSchema }), auth.register);
router.post('/login', authLimiter, validate({ body: loginSchema }), auth.login);
router.post('/refresh', refreshLimiter, validate({ body: refreshSchema }), auth.refresh);
router.post('/forgot-password', forgotPasswordLimiter, validate({ body: forgotPasswordSchema }), auth.forgotPassword);
router.post('/reset-password', resetPasswordLimiter, validate({ body: resetPasswordSchema }), auth.resetPassword);
router.post('/google', authLimiter, validate({ body: googleSchema }), auth.googleSignIn);
router.post('/apple', authLimiter, validate({ body: appleSchema }), auth.appleSignIn);
router.post('/guest', guestLimiter, auth.createGuest);
router.post('/upgrade', upgradeLimiter, authenticate, validate({ body: upgradeSchema }), auth.upgradeGuest);

export default router;
