import { Router } from 'express';
import { z } from 'zod';
import { validate } from '../middleware/validate.js';
import { authenticate } from '../middleware/authenticate.js';
import { requireFullAccount } from '../middleware/require-full-account.js';
import * as session from '../controllers/session.controller.js';

const router = Router();

// All session routes require authentication and a full (non-guest) account
router.use(authenticate, requireFullAccount);

// ─── Schemas ─────────────────────────────────────────────────────────────────

const sessionParamsSchema = z.object({
  id: z.string().uuid(),
});

const setParamsSchema = z.object({
  id: z.string().uuid(),
  setId: z.string().uuid(),
});

const listSessionsQuerySchema = z.object({
  cursor: z.string().min(1).optional(),
  limit: z
    .string()
    .optional()
    .transform((val) => (val !== undefined ? parseInt(val, 10) : 20))
    .pipe(z.number().int().min(1).max(100)),
  from: z.string().datetime({ offset: true }).optional(),
  to: z.string().datetime({ offset: true }).optional(),
  status: z.enum(['in_progress', 'completed', 'abandoned']).optional(),
});

const startSessionBodySchema = z
  .object({
    planId: z.string().uuid().optional(),
    planDayId: z.string().uuid().optional(),
    startedAt: z.string().datetime({ offset: true }).optional(),
  })
  .superRefine((data, ctx) => {
    if (data.planDayId && !data.planId) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['planId'],
        message: 'planId is required when planDayId is provided',
      });
    }
    if (data.startedAt && new Date(data.startedAt) > new Date()) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['startedAt'],
        message: 'startedAt cannot be in the future',
      });
    }
  });

const updateSessionBodySchema = z
  .object({
    notes: z.string().max(1000).nullable().optional(),
    status: z.literal('abandoned').optional(),
  })
  .refine((data) => Object.keys(data).length > 0 && Object.values(data).some((v) => v !== undefined), {
    message: 'At least one field must be provided',
  });

// Shared optional performance fields for set logging.
// Notes live on ExerciseLog (not SetLog), so they are not included here.
const setFieldsSchema = z.object({
  reps: z.number().int().min(1).optional(),
  weightKg: z.number().min(0).optional(),
  durationSec: z.number().int().min(1).max(86400).optional(),
  distanceM: z.number().min(0).optional(),
  paceSecPerKm: z.number().min(0).optional(),
  heartRate: z.number().int().min(1).max(300).optional(),
  rpe: z.number().int().min(1).max(10).optional(),
  tempo: z.string().max(20).optional(),
  isWarmup: z.boolean().optional(),
  completedAt: z.string().datetime({ offset: true }).optional(),
});

const logSetBodySchema = setFieldsSchema
  .extend({
    exerciseId: z.string().uuid(),
    setNumber: z.number().int().min(1),
  })
  .superRefine((data, ctx) => {
    const performanceFields = ['reps', 'weightKg', 'durationSec', 'distanceM', 'paceSecPerKm'] as const;
    const hasPerformanceData = performanceFields.some((f) => data[f] !== undefined);
    if (!hasPerformanceData) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'At least one performance field must be provided (reps, weightKg, durationSec, distanceM, or paceSecPerKm)',
      });
    }
  });

// For updates, fields are nullable to allow clearing stored values.
const updateSetBodySchema = z
  .object({
    reps: z.number().int().min(1).nullable().optional(),
    weightKg: z.number().min(0).nullable().optional(),
    durationSec: z.number().int().min(1).max(86400).nullable().optional(),
    distanceM: z.number().min(0).nullable().optional(),
    paceSecPerKm: z.number().min(0).nullable().optional(),
    heartRate: z.number().int().min(1).max(300).nullable().optional(),
    rpe: z.number().int().min(1).max(10).nullable().optional(),
    tempo: z.string().max(20).nullable().optional(),
    isWarmup: z.boolean().optional(),
    completedAt: z.string().datetime({ offset: true }).nullable().optional(),
  })
  .refine((data) => Object.keys(data).length > 0 && Object.values(data).some((v) => v !== undefined), {
    message: 'At least one field must be provided',
  });

const completeSessionBodySchema = z
  .object({
    completedAt: z.string().datetime({ offset: true }).optional(),
    durationSec: z.number().int().min(1).max(86400).optional(),
    notes: z.string().max(1000).nullable().optional(),
  })
  .superRefine((data, ctx) => {
    if (data.completedAt && new Date(data.completedAt) > new Date()) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['completedAt'],
        message: 'completedAt cannot be in the future',
      });
    }
  });

// ─── Routes ───────────────────────────────────────────────────────────────────

router.post('/', validate({ body: startSessionBodySchema }), session.startSession);
router.get('/', validate({ query: listSessionsQuerySchema }), session.listSessions);
router.get('/:id', validate({ params: sessionParamsSchema }), session.getSession);
// PATCH for partial updates per API conventions (CLAUDE.md)
router.patch('/:id', validate({ params: sessionParamsSchema, body: updateSessionBodySchema }), session.updateSession);
router.post('/:id/sets', validate({ params: sessionParamsSchema, body: logSetBodySchema }), session.logSet);
router.patch('/:id/sets/:setId', validate({ params: setParamsSchema, body: updateSetBodySchema }), session.updateSet);
router.delete('/:id/sets/:setId', validate({ params: setParamsSchema }), session.deleteSet);
router.post('/:id/complete', validate({ params: sessionParamsSchema, body: completeSessionBodySchema }), session.completeSession);

export default router;
