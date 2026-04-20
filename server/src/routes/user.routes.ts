import { Router } from 'express';
import { z } from 'zod';
import * as user from '../controllers/user.controller.js';
import { authenticate } from '../middleware/authenticate.js';
import { requireFullAccount } from '../middleware/require-full-account.js';
import { profileUpdateLimiter, deleteAccountLimiter } from '../middleware/rate-limiter.js';
import { validate } from '../middleware/validate.js';

const router = Router();

const updateProfileBody = z
  .object({
    displayName: z.string().min(1).max(50).nullable().optional(),
    // Restrict to HTTPS only — http:// allows MITM; data:/file:// bypass the S3 upload
    // flow; and arbitrary URLs become an SSRF vector when Phase 2 fetches avatarUrls
    // server-side for thumbnail generation.
    avatarUrl: z
      .string()
      .url()
      .max(2048)
      .refine((url) => url.startsWith('https://'), 'Avatar URL must use HTTPS')
      .nullable()
      .optional(),
    bio: z.string().max(500).nullable().optional(),
  })
  .refine((data) => Object.values(data).some((v) => v !== undefined), {
    message: 'At least one field must be provided',
  });

const updatePreferencesBody = z
  .object({
    units: z.enum(['metric', 'imperial']).optional(),
    theme: z.enum(['light', 'dark', 'system']).optional(),
    notifications: z
      .object({
        workoutReminders: z.boolean().optional(),
        streakAlerts: z.boolean().optional(),
        weeklyReport: z.boolean().optional(),
      })
      .optional(),
  })
  .refine((data) => Object.values(data).some((v) => v !== undefined), {
    message: 'At least one preference field must be provided',
  });

const deleteAccountBody = z.object({
  password: z.string().min(1).optional(),         // email accounts
  idToken: z.string().min(1).optional(),          // Google accounts
  identityToken: z.string().min(1).optional(),    // Apple accounts
  confirmPhrase: z.literal('DELETE MY ACCOUNT'),
});

router.get('/me', authenticate, user.getProfile);

// PATCH — partial update per project conventions (PUT is full replacement)
router.patch(
  '/me',
  authenticate,
  requireFullAccount,
  profileUpdateLimiter,
  validate({ body: updateProfileBody }),
  user.updateProfile,
);

router.patch(
  '/me/preferences',
  authenticate,
  requireFullAccount,
  profileUpdateLimiter,
  validate({ body: updatePreferencesBody }),
  user.updatePreferences,
);

router.get('/me/stats', authenticate, user.getStats);

router.delete(
  '/me',
  authenticate,
  requireFullAccount,
  deleteAccountLimiter,
  validate({ body: deleteAccountBody }),
  user.deleteAccount,
);

export default router;
