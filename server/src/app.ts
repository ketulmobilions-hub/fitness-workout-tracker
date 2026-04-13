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
app.use(
  cors({
    origin: env.CORS_ORIGIN ?? '*',
  }),
);
app.use(express.json({ limit: '100kb' }));
app.use(express.urlencoded({ extended: true, limit: '100kb' }));

app.use('/api/v1', routes);

// Catch-all for undefined routes — ensures RFC 7807 JSON 404 instead of Express's default HTML.
app.use((_req, _res, next) => next(new AppError(404, 'Route not found')));

app.use(errorHandler);

export default app;
