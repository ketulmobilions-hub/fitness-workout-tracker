import app from './app.js';
import { env } from './utils/env.js';
import { prisma, pool } from './lib/prisma.js';
import { startStreakWorker, stopStreakWorker } from './workers/streak.worker.js';

const port = env.PORT;

const server = app.listen(port, () => {
  console.log(`Server running on port ${port} in ${env.NODE_ENV} mode`);
});

// Start background job workers only when Redis is available.
if (env.REDIS_URL) {
  startStreakWorker().catch((err: unknown) => {
    console.error('Failed to start streak worker:', err);
  });
}

// Issue 14: guard against double-invocation when SIGTERM + SIGINT arrive together
// (common in container orchestrators). A second call would re-close already-closed
// resources and potentially throw inside the shutdown callback.
let isShuttingDown = false;

function shutdown(signal: string): void {
  if (isShuttingDown) return;
  isShuttingDown = true;

  console.log(`\n${signal} received. Shutting down gracefully...`);
  server.close(async () => {
    if (env.REDIS_URL) {
      await stopStreakWorker();
    }
    await prisma.$disconnect();
    await pool.end();
    console.log('Server closed.');
    process.exit(0);
  });
  setTimeout(() => {
    console.error('Forced shutdown after timeout.');
    process.exit(1);
  }, 10_000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

process.on('unhandledRejection', (reason) => {
  console.error('Unhandled Rejection:', reason);
  shutdown('unhandledRejection');
});

process.on('uncaughtException', (err) => {
  console.error('Uncaught Exception:', err);
  process.exit(1);
});
