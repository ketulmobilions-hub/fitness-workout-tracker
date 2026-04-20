import type { Request, Response } from 'express';
import { prisma } from '../lib/prisma.js';
import { sendSuccess } from '../utils/response.js';

export const getMuscleGroups = async (_req: Request, res: Response): Promise<void> => {
  const muscleGroups = await prisma.muscleGroup.findMany({
    orderBy: [{ bodyRegion: 'asc' }, { displayName: 'asc' }],
    // Explicit upper bound: muscle groups are seeded reference data that rarely changes.
    // A hard cap prevents an unbounded table scan if the table ever grows unexpectedly.
    take: 200,
  });

  // Muscle groups are seeded reference data that rarely changes. Cache on the client
  // to avoid a DB round-trip on every exercise creation screen open. max-age is kept
  // deliberately short (60s) so that any future admin-driven additions become visible
  // quickly; stale-while-revalidate lets cached clients refresh in the background.
  res.setHeader('Cache-Control', 'public, max-age=60, stale-while-revalidate=600');

  sendSuccess(res, { muscleGroups });
};
