import type { Request, Response } from 'express';
import { sendSuccess } from '../utils/response.js';

// Weight classes are static reference data — no DB lookup needed.
// Classes sourced from official IPF/USAPL rulebooks (2024 edition).
const WEIGHT_CLASSES: Record<string, Record<string, number[]>> = {
  IPF: {
    M: [53, 59, 66, 74, 83, 93, 105, 120],
    F: [43, 47, 52, 57, 63, 69, 76, 84],
  },
  USAPL: {
    M: [53, 59, 66, 74, 83, 93, 105, 120],
    F: [43, 47, 52, 57, 63, 69, 76, 84],
  },
  CPU: {
    M: [53, 59, 66, 74, 83, 93, 105, 120],
    F: [43, 47, 52, 57, 63, 69, 76, 84],
  },
  RPS: {
    M: [52, 56, 60, 67.5, 75, 82.5, 90, 100, 110, 125],
    F: [44, 48, 52, 56, 60, 67.5, 75, 82.5, 90],
  },
  WRPF: {
    M: [52, 56, 60, 67.5, 75, 82.5, 90, 100, 110, 125],
    F: [44, 48, 52, 56, 60, 67.5, 75, 82.5, 90],
  },
};

export const getWeightClasses = (_req: Request, res: Response): void => {
  sendSuccess(res, { weightClasses: WEIGHT_CLASSES });
};
