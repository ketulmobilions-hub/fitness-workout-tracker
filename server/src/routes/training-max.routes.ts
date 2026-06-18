import { Router } from 'express';
import { z } from 'zod';
import { validate } from '../middleware/validate.js';
import { authenticate } from '../middleware/authenticate.js';
import { requireFullAccount } from '../middleware/require-full-account.js';
import * as trainingMax from '../controllers/training-max.controller.js';

const router = Router();

router.use(authenticate, requireFullAccount);

const paramsSchema = z.object({
  exerciseId: z.string().uuid(),
});

// percentageOf1rm as Float — 87.5 is a common program percentage (e.g. 5/3/1)
const bodySchema = z.object({
  trainingMaxKg: z.number().positive().max(1000),
  percentageOf1rm: z.number().min(50).max(100).optional(),
});

router.get('/', trainingMax.list);
router.put(
  '/:exerciseId',
  validate({ params: paramsSchema, body: bodySchema }),
  trainingMax.upsert,
);

export default router;
