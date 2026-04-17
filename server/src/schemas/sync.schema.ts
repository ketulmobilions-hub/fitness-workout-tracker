import { z } from 'zod';

// ─── Push ────────────────────────────────────────────────────────────────────

const syncOperationSchema = z.enum(['create', 'update', 'delete']);

const supportedTablesSchema = z.enum([
  'workout_sessions',
  'exercise_logs',
  'set_logs',
  'workout_plans',
  'plan_days',
  'plan_day_exercises',
]);

export const syncPushBodySchema = z.object({
  // Server accepts at most 100 items per request.
  // The Flutter client sends batches of 20 (see _batchSize in sync_service.dart).
  items: z
    .array(
      z.object({
        id: z.string().uuid(),
        entityTable: supportedTablesSchema,
        recordId: z.string().uuid(),
        operation: syncOperationSchema,
        payload: z.record(z.string(), z.unknown()),
      }),
    )
    .min(1)
    .max(100),
});

// ─── Pull ────────────────────────────────────────────────────────────────────

export const syncPullQuerySchema = z.object({
  // ISO 8601 datetime with timezone offset (e.g. "2024-01-01T00:00:00Z").
  // Omit for a full sync (initial login).
  since: z.string().datetime({ offset: true }).optional(),
});

export type SyncPushBody = z.infer<typeof syncPushBodySchema>;
export type SyncPullQuery = z.infer<typeof syncPullQuerySchema>;
export type SyncOperation = z.infer<typeof syncOperationSchema>;
export type SupportedTable = z.infer<typeof supportedTablesSchema>;
