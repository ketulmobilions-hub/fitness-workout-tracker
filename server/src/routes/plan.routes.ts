import { Router } from 'express';
import { z } from 'zod';
import { validate } from '../middleware/validate.js';
import { authenticate } from '../middleware/authenticate.js';
import { requireFullAccount } from '../middleware/require-full-account.js';
import * as plan from '../controllers/plan.controller.js';

const router = Router();

// All plan routes require authentication and a full (non-guest) account
router.use(authenticate, requireFullAccount);

// ─── Schemas ─────────────────────────────────────────────────────────────────

const planParamsSchema = z.object({
  id: z.string().uuid(),
});

// Params for exercise sub-routes — :planDayExId is the plan_day_exercise record ID
const planDayExParamsSchema = z.object({
  id: z.string().uuid(),
  planDayExId: z.string().uuid(),
});

const listPlansQuerySchema = z.object({
  cursor: z.string().min(1).optional(),
  limit: z
    .string()
    .optional()
    .transform((val) => (val !== undefined ? parseInt(val, 10) : 20))
    .pipe(z.number().int().min(1).max(100)),
});

const daySchema = z.object({
  // 0 = Sunday … 6 = Saturday, matching JavaScript Date.getDay() convention
  dayOfWeek: z.number().int().min(0).max(6),
  // weekNumber is used for multi-week recurring plans (week 1, week 2, …)
  weekNumber: z.number().int().min(1).optional(),
  name: z.string().min(1).max(100).optional(),
  sortOrder: z.number().int().min(0),
});

const createPlanBodySchema = z
  .object({
    name: z.string().min(1).max(100),
    description: z.string().max(500).optional(),
    scheduleType: z.enum(['weekly', 'recurring']),
    weeksCount: z.number().int().min(1).max(52).optional(),
    days: z.array(daySchema).max(30).optional(),
  })
  .superRefine((data, ctx) => {
    if (data.scheduleType === 'recurring' && data.weeksCount === undefined) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['weeksCount'],
        message: 'weeksCount is required when scheduleType is "recurring"',
      });
    }
  });

const updatePlanBodySchema = z
  .object({
    name: z.string().min(1).max(100).optional(),
    description: z.string().max(500).optional(),
    scheduleType: z.enum(['weekly', 'recurring']).optional(),
    weeksCount: z.number().int().min(1).max(52).optional(),
    isActive: z.boolean().optional(),
  })
  .refine((data) => Object.values(data).some((v) => v !== undefined), {
    message: 'At least one field must be provided',
  })
  .superRefine((data, ctx) => {
    // If scheduleType is being switched to 'recurring', weeksCount must also be provided
    // (either in this request or it was already set — we can only validate what's sent).
    if (data.scheduleType === 'recurring' && data.weeksCount === undefined) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['weeksCount'],
        message: 'weeksCount is required when scheduleType is "recurring"',
      });
    }
  });

// targetReps format: a single number ("10") or a range ("8-12").
// Stored as a string so clients can display it directly (e.g., "8-12 reps").
const targetRepsSchema = z
  .string()
  .regex(/^\d+(-\d+)?$/, 'targetReps must be a number or range (e.g. "10" or "8-12")')
  .optional();

const addExerciseBodySchema = z.object({
  planDayId: z.string().uuid(),
  exerciseId: z.string().uuid(),
  sortOrder: z.number().int().min(0),
  targetSets: z.number().int().min(1).max(100).optional(),
  targetReps: targetRepsSchema,
  targetDurationSec: z.number().int().min(1).optional(),
  targetDistanceM: z.number().min(0).optional(),
  notes: z.string().max(500).optional(),
});

const updateExerciseBodySchema = z
  .object({
    sortOrder: z.number().int().min(0).optional(),
    targetSets: z.number().int().min(1).max(100).optional(),
    targetReps: targetRepsSchema,
    targetDurationSec: z.number().int().min(1).optional(),
    targetDistanceM: z.number().min(0).optional(),
    // null explicitly clears the notes field
    notes: z.string().max(500).nullable().optional(),
  })
  .refine((data) => Object.keys(data).length > 0 && Object.values(data).some((v) => v !== undefined), {
    message: 'At least one field must be provided',
  });

const reorderBodySchema = z.object({
  planDayId: z.string().uuid(),
  planDayExerciseIds: z.array(z.string().uuid()).min(1).max(100),
});

// ─── Routes ───────────────────────────────────────────────────────────────────

// Plan CRUD
router.post('/', validate({ body: createPlanBodySchema }), plan.createPlan);
router.get('/', validate({ query: listPlansQuerySchema }), plan.listPlans);
router.get('/:id', validate({ params: planParamsSchema }), plan.getPlan);
router.patch('/:id', validate({ params: planParamsSchema, body: updatePlanBodySchema }), plan.updatePlan);
router.delete('/:id', validate({ params: planParamsSchema }), plan.deletePlan);

// Exercise sub-routes
// NOTE: /reorder must be registered before /:planDayExId to avoid being caught as a param
router.post('/:id/exercises', validate({ params: planParamsSchema, body: addExerciseBodySchema }), plan.addExercise);
router.patch('/:id/exercises/reorder', validate({ params: planParamsSchema, body: reorderBodySchema }), plan.reorderExercises);
router.patch('/:id/exercises/:planDayExId', validate({ params: planDayExParamsSchema, body: updateExerciseBodySchema }), plan.updateExercise);
router.delete('/:id/exercises/:planDayExId', validate({ params: planDayExParamsSchema }), plan.removeExercise);

export default router;
