import { Router } from 'express';
import { z } from 'zod';
import { validate } from '../middleware/validate.js';
import { authenticate } from '../middleware/authenticate.js';
import { requireFullAccount } from '../middleware/require-full-account.js';
import * as exercise from '../controllers/exercise.controller.js';

const router = Router();

const paramsSchema = z.object({
  id: z.string().uuid(),
});

const listQuerySchema = z.object({
  // min(1) prevents an empty-string cursor from decoding to a meaningless empty value
  cursor: z.string().min(1).optional(),
  limit: z
    .string()
    .optional()
    .transform((val) => (val !== undefined ? parseInt(val, 10) : 20))
    .pipe(z.number().int().min(1).max(100)),
  search: z.string().min(1).max(200).optional(),
  muscle_group: z.string().min(1).max(100).optional(),
  exercise_type: z.enum(['strength', 'cardio', 'stretching']).optional(),
});

const muscleGroupEntrySchema = z.object({
  muscleGroupId: z.string().uuid(),
  isPrimary: z.boolean(),
});

// Shared superRefine: rejects duplicate muscleGroupId values in the submitted array
// so Prisma never attempts to insert two rows with the same composite PK (exerciseId, muscleGroupId).
function rejectDuplicateMuscleGroups(
  data: { muscleGroups?: Array<{ muscleGroupId: string; isPrimary: boolean }> },
  ctx: z.RefinementCtx,
): void {
  if (!data.muscleGroups) return;
  const seen = new Set<string>();
  data.muscleGroups.forEach((mg, i) => {
    if (seen.has(mg.muscleGroupId)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['muscleGroups', i, 'muscleGroupId'],
        message: 'Duplicate muscleGroupId — each muscle group may only appear once',
      });
    }
    seen.add(mg.muscleGroupId);
  });
}

// Base object schema shared by create and update — superRefine is applied separately
// to each so that .partial() can be called on the raw ZodObject before wrapping.
const exerciseBaseSchema = z.object({
  name: z.string().min(1).max(100),
  description: z.string().max(500).optional(),
  exerciseType: z.enum(['strength', 'cardio', 'stretching']),
  instructions: z.string().optional(),
  mediaUrl: z.string().url().optional(),
  muscleGroups: z.array(muscleGroupEntrySchema).max(10).optional(),
});

const createExerciseBodySchema = exerciseBaseSchema.superRefine(rejectDuplicateMuscleGroups);

const updateExerciseBodySchema = exerciseBaseSchema
  .partial()
  .superRefine(rejectDuplicateMuscleGroups)
  // Require at least one field so an empty body is rejected rather than silently no-op'd.
  .refine((data) => Object.values(data).some((v) => v !== undefined), {
    message: 'At least one field must be provided',
  });

// GET /exercises       — public, no auth required
// GET /exercises/:id   — public, no auth required
// POST /exercises      — authenticated full account only
// PATCH /exercises/:id — authenticated full account only (PATCH = partial update)
// DELETE /exercises/:id — authenticated full account only

router.get('/', validate({ query: listQuerySchema }), exercise.listExercises);
router.get('/:id', validate({ params: paramsSchema }), exercise.getExercise);
router.post(
  '/',
  authenticate,
  requireFullAccount,
  validate({ body: createExerciseBodySchema }),
  exercise.createExercise,
);
router.patch(
  '/:id',
  authenticate,
  requireFullAccount,
  validate({ params: paramsSchema, body: updateExerciseBodySchema }),
  exercise.updateExercise,
);
router.delete(
  '/:id',
  authenticate,
  requireFullAccount,
  validate({ params: paramsSchema }),
  exercise.deleteExercise,
);

export default router;
