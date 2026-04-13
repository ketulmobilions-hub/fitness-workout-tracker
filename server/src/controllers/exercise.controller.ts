import type { Request, Response } from 'express';
import { Prisma } from '../generated/prisma/client.js';
import { prisma } from '../lib/prisma.js';
import { AppError } from '../utils/errors.js';
import { sendSuccess } from '../utils/response.js';
import type { ExerciseType } from '../generated/prisma/enums.js';

// ─── Types ────────────────────────────────────────────────────────────────────

type ExerciseWithMuscleGroups = Prisma.ExerciseGetPayload<{
  include: { muscleGroups: { include: { muscleGroup: true } } };
}>;

type MappedExercise = {
  id: string;
  name: string;
  description: string | null;
  exerciseType: string;
  instructions: string | null;
  mediaUrl: string | null;
  isCustom: boolean;
  createdAt: string;
  updatedAt: string;
  muscleGroups: Array<{
    id: string;
    name: string;
    displayName: string;
    bodyRegion: string;
    isPrimary: boolean;
  }>;
};

type DecodedCursor = { id: string; name: string };

// ─── Helpers ──────────────────────────────────────────────────────────────────

function mapExercise(exercise: ExerciseWithMuscleGroups): MappedExercise {
  return {
    id: exercise.id,
    name: exercise.name,
    description: exercise.description,
    exerciseType: exercise.exerciseType,
    instructions: exercise.instructions,
    mediaUrl: exercise.mediaUrl,
    isCustom: exercise.isCustom,
    // createdBy is intentionally omitted — exposing creator UUIDs on a public endpoint
    // would leak user identifiers to unauthenticated callers.
    createdAt: exercise.createdAt.toISOString(),
    updatedAt: exercise.updatedAt.toISOString(),
    muscleGroups: exercise.muscleGroups.map((emg) => ({
      id: emg.muscleGroup.id,
      name: emg.muscleGroup.name,
      displayName: emg.muscleGroup.displayName,
      bodyRegion: emg.muscleGroup.bodyRegion,
      isPrimary: emg.isPrimary,
    })),
  };
}

const exerciseInclude = {
  muscleGroups: { include: { muscleGroup: true } },
} satisfies Prisma.ExerciseInclude;

function encodeCursor(exercise: ExerciseWithMuscleGroups): string {
  const payload: DecodedCursor = { id: exercise.id, name: exercise.name };
  return Buffer.from(JSON.stringify(payload)).toString('base64url');
}

function decodeCursor(cursor: string): DecodedCursor {
  try {
    const raw = Buffer.from(cursor, 'base64url').toString('utf8');
    const parsed = JSON.parse(raw) as unknown;
    if (
      typeof parsed === 'object' &&
      parsed !== null &&
      // Strictly two keys — no extra fields accepted
      Object.keys(parsed as object).length === 2 &&
      'id' in parsed &&
      'name' in parsed &&
      typeof (parsed as Record<string, unknown>).id === 'string' &&
      typeof (parsed as Record<string, unknown>).name === 'string'
    ) {
      return parsed as DecodedCursor;
    }
  } catch {
    // fall through to throw below
  }
  throw new AppError(400, 'Invalid or expired pagination cursor');
}

// ─── Handlers ─────────────────────────────────────────────────────────────────

export const listExercises = async (_req: Request, res: Response): Promise<void> => {
  const { cursor, limit, search, muscle_group, exercise_type } =
    res.locals.validated!.query as {
      cursor?: string;
      limit: number;
      search?: string;
      muscle_group?: string;
      exercise_type?: ExerciseType;
    };

  // Build filter conditions — composed with AND so each filter is independent
  const conditions: Prisma.ExerciseWhereInput[] = [];

  if (search) {
    conditions.push({
      OR: [
        { name: { contains: search, mode: 'insensitive' } },
        { description: { contains: search, mode: 'insensitive' } },
      ],
    });
  }

  if (muscle_group) {
    conditions.push({ muscleGroups: { some: { muscleGroup: { name: muscle_group } } } });
  }

  if (exercise_type) {
    conditions.push({ exerciseType: exercise_type });
  }

  // Keyset pagination: (name > cursorName) OR (name = cursorName AND id > cursorId)
  // This produces stable pages with compound (name, id) ordering without relying on
  // Prisma cursor/skip, which can silently skip or duplicate rows when a cursor row
  // is deleted between requests or when two exercises share the same name.
  if (cursor) {
    const decoded = decodeCursor(cursor);
    conditions.push({
      OR: [
        { name: { gt: decoded.name } },
        { AND: [{ name: decoded.name }, { id: { gt: decoded.id } }] },
      ],
    });
  }

  const where: Prisma.ExerciseWhereInput = conditions.length > 0 ? { AND: conditions } : {};

  const rows = await prisma.exercise.findMany({
    where,
    orderBy: [{ name: 'asc' }, { id: 'asc' }],
    take: limit + 1,
    include: exerciseInclude,
  });

  const hasMore = rows.length > limit;
  const data = hasMore ? rows.slice(0, limit) : rows;
  const nextCursor = hasMore ? encodeCursor(data.at(-1)!) : null;

  sendSuccess(res, {
    exercises: data.map(mapExercise),
    pagination: {
      next_cursor: nextCursor,
      has_more: hasMore,
      limit,
    },
  });
};

export const getExercise = async (_req: Request, res: Response): Promise<void> => {
  const { id } = res.locals.validated!.params as { id: string };

  const exercise = await prisma.exercise.findUnique({
    where: { id },
    include: exerciseInclude,
  });

  if (!exercise) {
    throw new AppError(404, 'Exercise not found');
  }

  sendSuccess(res, { exercise: mapExercise(exercise) });
};

export const createExercise = async (_req: Request, res: Response): Promise<void> => {
  const { userId } = res.locals.auth!;
  const { name, description, exerciseType, instructions, mediaUrl, muscleGroups } =
    res.locals.validated!.body as {
      name: string;
      description?: string;
      exerciseType: ExerciseType;
      instructions?: string;
      mediaUrl?: string;
      muscleGroups?: Array<{ muscleGroupId: string; isPrimary: boolean }>;
    };

  // Validate that all supplied muscle group IDs exist in the DB.
  // Duplicate IDs are already rejected by the Zod schema; this check ensures
  // the IDs themselves are valid foreign keys.
  if (muscleGroups && muscleGroups.length > 0) {
    const ids = muscleGroups.map((mg) => mg.muscleGroupId);
    const found = await prisma.muscleGroup.findMany({ where: { id: { in: ids } } });
    if (found.length !== ids.length) {
      throw new AppError(422, 'One or more muscle group IDs are invalid');
    }
  }

  const exercise = await prisma.exercise.create({
    data: {
      name,
      description,
      exerciseType,
      instructions,
      mediaUrl,
      isCustom: true,
      createdBy: userId,
      muscleGroups: muscleGroups
        ? {
            create: muscleGroups.map((mg) => ({
              muscleGroupId: mg.muscleGroupId,
              isPrimary: mg.isPrimary,
            })),
          }
        : undefined,
    },
    include: exerciseInclude,
  });

  sendSuccess(res, { exercise: mapExercise(exercise) }, 201);
};

export const updateExercise = async (_req: Request, res: Response): Promise<void> => {
  const { userId } = res.locals.auth!;
  const { id } = res.locals.validated!.params as { id: string };
  const { name, description, exerciseType, instructions, mediaUrl, muscleGroups } =
    res.locals.validated!.body as {
      name?: string;
      description?: string;
      exerciseType?: ExerciseType;
      instructions?: string;
      mediaUrl?: string;
      muscleGroups?: Array<{ muscleGroupId: string; isPrimary: boolean }>;
    };

  const existing = await prisma.exercise.findUnique({ where: { id } });

  if (!existing) {
    throw new AppError(404, 'Exercise not found');
  }

  // Check isCustom before ownership — system exercises have createdBy: null,
  // which would incorrectly pass the ownership comparison against a real userId.
  if (!existing.isCustom) {
    throw new AppError(403, 'System exercises cannot be modified');
  }

  if (existing.createdBy !== userId) {
    throw new AppError(403, 'You do not have permission to modify this exercise');
  }

  // Validate supplied muscle group IDs when the array is non-empty.
  // An explicit [] is a valid "clear all" instruction and needs no DB validation.
  if (muscleGroups !== undefined && muscleGroups.length > 0) {
    const ids = muscleGroups.map((mg) => mg.muscleGroupId);
    const found = await prisma.muscleGroup.findMany({ where: { id: { in: ids } } });
    if (found.length !== ids.length) {
      throw new AppError(422, 'One or more muscle group IDs are invalid');
    }
  }

  const scalarData: Prisma.ExerciseUpdateInput = {};
  if (name !== undefined) scalarData.name = name;
  if (description !== undefined) scalarData.description = description;
  if (exerciseType !== undefined) scalarData.exerciseType = exerciseType;
  if (instructions !== undefined) scalarData.instructions = instructions;
  if (mediaUrl !== undefined) scalarData.mediaUrl = mediaUrl;

  let updated: ExerciseWithMuscleGroups;

  // Shared P2025 handler: if the exercise is deleted between the ownership check
  // above and the write below, return a 404 rather than propagating a 500.
  function handleUpdateError(err: unknown): never {
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2025') {
      throw new AppError(404, 'Exercise not found');
    }
    throw err;
  }

  if (muscleGroups !== undefined) {
    // Use interactive transaction so the return type is fully inferred — no unsafe cast.
    // deleteMany first, then update with new associations.
    try {
      updated = await prisma.$transaction(async (tx) => {
        await tx.exerciseMuscleGroup.deleteMany({ where: { exerciseId: id } });
        return tx.exercise.update({
          where: { id },
          data: {
            ...scalarData,
            muscleGroups: {
              create: muscleGroups.map((mg) => ({
                muscleGroupId: mg.muscleGroupId,
                isPrimary: mg.isPrimary,
              })),
            },
          },
          include: exerciseInclude,
        });
      });
    } catch (err) {
      handleUpdateError(err);
    }
  } else {
    try {
      updated = await prisma.exercise.update({
        where: { id },
        data: scalarData,
        include: exerciseInclude,
      });
    } catch (err) {
      handleUpdateError(err);
    }
  }

  sendSuccess(res, { exercise: mapExercise(updated) });
};

export const deleteExercise = async (_req: Request, res: Response): Promise<void> => {
  const { userId } = res.locals.auth!;
  const { id } = res.locals.validated!.params as { id: string };

  const existing = await prisma.exercise.findUnique({ where: { id } });

  if (!existing) {
    throw new AppError(404, 'Exercise not found');
  }

  // Check isCustom before ownership for the same reason as updateExercise.
  if (!existing.isCustom) {
    throw new AppError(403, 'System exercises cannot be deleted');
  }

  if (existing.createdBy !== userId) {
    throw new AppError(403, 'You do not have permission to delete this exercise');
  }

  // Guard against the TOCTOU race (concurrent delete requests): if the record
  // was deleted between findUnique and here, handle P2025 gracefully.
  try {
    await prisma.exercise.delete({ where: { id } });
  } catch (err) {
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2025') {
      throw new AppError(404, 'Exercise not found');
    }
    throw err;
  }

  res.status(204).end();
};
