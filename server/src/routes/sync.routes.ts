import { Router } from 'express';
import { authenticate } from '../middleware/authenticate.js';
import { requireFullAccount } from '../middleware/require-full-account.js';
import { validate } from '../middleware/validate.js';
import { syncPushBodySchema, syncPullQuerySchema } from '../schemas/sync.schema.js';
import * as sync from '../controllers/sync.controller.js';

const router = Router();

// POST /api/v1/sync/push — flush locally-queued changes to the server.
// Client is source of truth: payloads are upserted as-is (local wins).
router.post(
  '/push',
  authenticate,
  requireFullAccount,
  validate({ body: syncPushBodySchema }),
  sync.push,
);

// GET /api/v1/sync/pull — download server changes since a timestamp.
// Omit `since` for a full initial sync (new install / first login).
router.get(
  '/pull',
  authenticate,
  requireFullAccount,
  validate({ query: syncPullQuerySchema }),
  sync.pull,
);

export default router;
