import { Router } from 'express';
import { z } from 'zod';
import { authenticate } from '../middleware/authenticate.js';
import { validate } from '../middleware/validate.js';
import { getStreak, getStreakHistory } from '../controllers/streak.controller.js';

const router = Router();

router.get('/', authenticate, getStreak);

router.get(
  '/history',
  authenticate,
  validate({
    query: z
      .object({
        year: z.coerce.number().int().min(2020).max(2100),
        month: z.coerce.number().int().min(1).max(12),
      })
      .refine(
        ({ year, month }) => {
          const now = new Date();
          const requested = new Date(Date.UTC(year, month - 1, 1));
          // Allow up to one month ahead of the current UTC month.
          const nextMonth = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1));
          return requested <= nextMonth;
        },
        { message: 'Cannot request streak history more than one month in the future' },
      ),
  }),
  getStreakHistory,
);

export default router;
