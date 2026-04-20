// Job name constant shared between the worker and any code that enqueues jobs.
// The Queue instance itself is owned and closed by streak.worker.ts to ensure
// its lifecycle is tied to the server's startup/shutdown sequence.
export const DAILY_STREAK_CHECK_JOB = 'daily-streak-check';
