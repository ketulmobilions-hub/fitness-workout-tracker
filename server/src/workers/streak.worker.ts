import { Worker, Queue } from 'bullmq';
import { getBullMQConnection } from '../lib/bullmq.js';
import { DAILY_STREAK_CHECK_JOB } from '../queues/streak.queue.js';
import { runDailyStreakCheck } from '../jobs/daily-streak-check.js';

// Module-level refs so stopStreakWorker never creates new connections during
// shutdown (Issue 2: stop must not call getStreakQueue() if start never ran).
let worker: Worker | null = null;
let queue: Queue | null = null;

export async function startStreakWorker(): Promise<void> {
  const connection = getBullMQConnection();

  // Own the queue here so its lifecycle is tied to startStreakWorker/stopStreakWorker.
  queue = new Queue('streak', { connection });

  // concurrency: 1 prevents a second job instance from starting if the previous
  // one is still running past its scheduled interval (guards the N+1 overlap risk).
  worker = new Worker(
    'streak',
    async (job) => {
      if (job.name === DAILY_STREAK_CHECK_JOB) {
        await runDailyStreakCheck();
      }
    },
    { connection, concurrency: 1 },
  );

  worker.on('completed', (job) => {
    console.log(`Streak job ${job.id} (${job.name}) completed`);
  });
  worker.on('failed', (job, err) => {
    console.error(`Streak job ${job?.id} (${job?.name}) failed:`, err.message);
  });

  // Register the daily repeatable job (00:05 UTC).
  // If scheduler registration fails, log the error but don't crash the server —
  // the worker is still running and can process manually enqueued jobs.
  // Issue 1: propagate the error visibly instead of silently swallowing it.
  try {
    await queue.upsertJobScheduler(
      'daily-streak-check-scheduler',
      { pattern: '5 0 * * *' },
      { name: DAILY_STREAK_CHECK_JOB, opts: { removeOnComplete: 10, removeOnFail: 5 } },
    );
    console.log('Streak worker started (daily job scheduled at 00:05 UTC)');
  } catch (err) {
    console.error(
      'Streak worker: failed to register daily job scheduler — missed streaks will not reset automatically until next restart:',
      err,
    );
  }
}

export async function stopStreakWorker(): Promise<void> {
  await worker?.close();
  await queue?.close();
  worker = null;
  queue = null;
  console.log('Streak worker stopped');
}
