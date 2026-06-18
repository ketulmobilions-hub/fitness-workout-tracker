import { Router } from 'express';
import { z } from 'zod';
import { validate } from '../middleware/validate.js';
import { authenticate } from '../middleware/authenticate.js';
import { requireFullAccount } from '../middleware/require-full-account.js';
import * as competition from '../controllers/competition.controller.js';

const router = Router();

router.use(authenticate, requireFullAccount);

// ─── Schemas ─────────────────────────────────────────────────────────────────

const idParamsSchema = z.object({
  id: z.string().uuid(),
});

const createBodySchema = z.object({
  name: z.string().min(1).max(200),
  federation: z.string().max(100).optional(),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'date must be YYYY-MM-DD'),
  location: z.string().max(200).optional(),
  weightClassKg: z.number().positive().optional(),
  bodyweightKg: z.number().positive().optional(),
  division: z.string().max(100).optional(),
});

const updateBodySchema = createBodySchema.partial().extend({
  status: z.enum(['upcoming', 'completed']).optional(),
});

const attemptBodySchema = z.object({
  liftType: z.enum(['squat', 'bench', 'deadlift']),
  attemptNumber: z.number().int().min(1).max(3),
  weightKg: z.number().positive().max(1000),
  result: z.enum(['good_lift', 'no_lift', 'not_taken']),
});

// ─── Routes ──────────────────────────────────────────────────────────────────

router.get('/', competition.list);
router.post('/', validate({ body: createBodySchema }), competition.create);
router.get('/:id', validate({ params: idParamsSchema }), competition.getOne);
router.patch(
  '/:id',
  validate({ params: idParamsSchema, body: updateBodySchema }),
  competition.update,
);
router.post(
  '/:id/attempts',
  validate({ params: idParamsSchema, body: attemptBodySchema }),
  competition.logAttempt,
);

export default router;
