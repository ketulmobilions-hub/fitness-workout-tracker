import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import routes from './routes/index.js';
import { requestLogger } from './middleware/request-logger.js';
import { globalLimiter } from './middleware/rate-limiter.js';
import { errorHandler } from './middleware/error-handler.js';
import { AppError } from './utils/errors.js';
import { env } from './utils/env.js';

const app = express();

// Trust one proxy hop (Render / AWS ALB) so req.ip reflects the real client IP.
// Required for rate limiting to key on the correct address.
app.set('trust proxy', 1);

app.use(requestLogger);
app.use(globalLimiter);
app.use(helmet());

// CORS allowlist: explicit CORS_ORIGINS, or just the frontend origin by default.
// Requests with no Origin header (curl, server-to-server, same-origin) are allowed.
const corsOrigins =
  env.CORS_ORIGIN?.split(',')
    .map(o => o.trim())
    .filter(Boolean) ?? [];
const allowedOrigins = corsOrigins.length > 0 ? corsOrigins : [env.FRONTEND_URL];
app.use(
  cors({
    origin(origin, callback) {
      if (!origin || allowedOrigins.includes(origin)) return callback(null, true);
      callback(new Error('Not allowed by CORS'));
    },
    credentials: true,
  })
);
app.use(express.json({ limit: '100kb' }));
app.use(express.urlencoded({ extended: true, limit: '100kb' }));

app.use('/api/v1', routes);

// Catch-all for undefined routes — ensures RFC 7807 JSON 404 instead of Express's default HTML.
app.use((_req, _res, next) => next(new AppError(404, 'Route not found')));

app.use(errorHandler);

export default app;
