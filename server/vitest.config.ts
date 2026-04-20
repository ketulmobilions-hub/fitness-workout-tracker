import { defineConfig } from 'vitest/config';
import { config } from 'dotenv';

// Load .env.test before vitest processes any test files so env.ts parses the
// correct values at module-evaluation time.
config({ path: '.env.test' });

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    setupFiles: ['./src/test/setup.ts'],
    // Run test files sequentially to avoid cross-test DB state issues without
    // requiring a dedicated test database.
    fileParallelism: false,
  },
});
