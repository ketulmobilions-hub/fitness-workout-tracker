import { Router } from 'express';
import { z } from 'zod';
import { validate } from '../middleware/validate.js';
import { authenticate } from '../middleware/authenticate.js';
import { requireFullAccount } from '../middleware/require-full-account.js';
import * as progress from '../controllers/progress.controller.js';

const router = Router();

// All progress routes require authentication and a full (non-guest) account
router.use(authenticate, requireFullAccount);

// ─── Schemas ─────────────────────────────────────────────────────────────────

const overviewQuerySchema = z.object({
  // UTC offset in minutes (e.g. -300 for EST, 330 for IST). Used to align
  // week/month boundaries with the user's local calendar day.
  utc_offset: z.coerce.number().int().min(-720).max(840).default(0),
});

const exerciseProgressParamsSchema = z.object({
  id: z.string().uuid(),
});

const exerciseProgressQuerySchema = z.object({
  period: z.enum(['1m', '3m', '6m', '1y', 'all']).default('3m'),
});

const personalRecordsQuerySchema = z.object({
  exercise_id: z.string().uuid().optional(),
  record_type: z.enum(['max_weight', 'max_reps', 'max_volume', 'best_pace']).optional(),
});

const volumeQuerySchema = z.object({
  period: z.enum(['1w', '1m', '3m', '6m', '1y']).default('1m'),
  granularity: z.enum(['daily', 'weekly', 'monthly']).optional(),
});

// ─── Routes ──────────────────────────────────────────────────────────────────

router.get('/overview', validate({ query: overviewQuerySchema }), progress.getOverview);
router.get(
  '/exercise/:id',
  validate({ params: exerciseProgressParamsSchema, query: exerciseProgressQuerySchema }),
  progress.getExerciseProgress,
);
router.get('/personal-records', validate({ query: personalRecordsQuerySchema }), progress.getPersonalRecords);
router.get('/volume', validate({ query: volumeQuerySchema }), progress.getVolume);

export default router;
