import morgan from 'morgan';
import type { Request, Response } from 'express';
import { env } from '../utils/env.js';

const skip = (req: Request, _res: Response): boolean => req.path === '/api/v1/health';

export const requestLogger = morgan(env.NODE_ENV === 'production' ? 'combined' : 'dev', { skip });
