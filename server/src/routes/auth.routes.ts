import { Router } from 'express';
import { z } from 'zod';
import { authLimiter, forgotPasswordLimiter, refreshLimiter, resetPasswordLimiter } from '../middleware/rate-limiter.js';
import { validate } from '../middleware/validate.js';
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

export default router;
