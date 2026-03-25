import type { Request, Response } from 'express';
import type { HealthResponse } from '../types/index.js';

export const getHealth = (_req: Request, res: Response): void => {
  const response: HealthResponse = {
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
  };
  res.status(200).json(response);
};
