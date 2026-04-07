import 'dotenv/config';
import bcrypt from 'bcryptjs';
import { PrismaClient } from '../src/generated/prisma/client.js';
import { ExerciseType, ScheduleType } from '../src/generated/prisma/enums.js';
import { PrismaPg } from '@prisma/adapter-pg';
import pg from 'pg';

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function main(): Promise<void> {
  // Clean existing data in dependency order (outside transaction — idempotent)
  await prisma.syncQueue.deleteMany();
  await prisma.streakHistory.deleteMany();
  await prisma.streak.deleteMany();
  await prisma.personalRecord.deleteMany();
  await prisma.setLog.deleteMany();
  await prisma.exerciseLog.deleteMany();
  await prisma.workoutSession.deleteMany();
  await prisma.planDayExercise.deleteMany();
  await prisma.planDay.deleteMany();
  await prisma.workoutPlan.deleteMany();
  await prisma.exerciseMuscleGroup.deleteMany();
  await prisma.exercise.deleteMany();
  await prisma.muscleGroup.deleteMany();
  await prisma.user.deleteMany();

  // All inserts in a single transaction — aborts cleanly if anything fails
  await prisma.$transaction(async (tx) => {
    // ─── Users ─────────────────────────────────────────────
    // Plain-text password for dev account: "password123"
    const passwordHash = await bcrypt.hash('password123', 10);

    const user = await tx.user.create({
      data: {
        email: 'dev@example.com',
        passwordHash,
        displayName: 'Dev User',
        authProvider: 'email',
        isGuest: false,
      },
    });

    await tx.user.create({
      data: {
        authProvider: 'guest',
        isGuest: true,
        displayName: 'Guest User',
      },
    });

    // ─── Muscle Groups ──────────────────────────────────────
    const muscleGroupData = [
      { name: 'chest', displayName: 'Chest', bodyRegion: 'upper' },
      { name: 'back', displayName: 'Back', bodyRegion: 'upper' },
      { name: 'shoulders', displayName: 'Shoulders', bodyRegion: 'upper' },
      { name: 'biceps', displayName: 'Biceps', bodyRegion: 'upper' },
      { name: 'triceps', displayName: 'Triceps', bodyRegion: 'upper' },
      { name: 'quadriceps', displayName: 'Quadriceps', bodyRegion: 'lower' },
      { name: 'hamstrings', displayName: 'Hamstrings', bodyRegion: 'lower' },
      { name: 'glutes', displayName: 'Glutes', bodyRegion: 'lower' },
      { name: 'calves', displayName: 'Calves', bodyRegion: 'lower' },
      { name: 'core', displayName: 'Core', bodyRegion: 'core' },
    ];

    const muscleGroups: Record<string, string> = {};
    for (const mg of muscleGroupData) {
      const created = await tx.muscleGroup.create({ data: mg });
      muscleGroups[mg.name] = created.id;
    }

    // ─── Exercises ──────────────────────────────────────────
    const exerciseData = [
      {
        name: 'Barbell Bench Press',
        exerciseType: ExerciseType.strength,
        description: 'Compound chest exercise',
        instructions: 'Lie on bench, grip bar shoulder-width, lower to chest, press up.',
        muscles: [
          { name: 'chest', primary: true },
          { name: 'triceps', primary: false },
          { name: 'shoulders', primary: false },
        ],
      },
      {
        name: 'Barbell Back Squat',
        exerciseType: ExerciseType.strength,
        description: 'Compound leg exercise',
        instructions: 'Bar on upper back, squat down to parallel, stand up.',
        muscles: [
          { name: 'quadriceps', primary: true },
          { name: 'glutes', primary: false },
          { name: 'hamstrings', primary: false },
        ],
      },
      {
        name: 'Conventional Deadlift',
        exerciseType: ExerciseType.strength,
        description: 'Full body compound lift',
        instructions: 'Grip bar, hinge at hips, lift to lockout.',
        muscles: [
          { name: 'back', primary: true },
          { name: 'hamstrings', primary: true },
          { name: 'glutes', primary: false },
        ],
      },
      {
        name: 'Overhead Press',
        exerciseType: ExerciseType.strength,
        description: 'Compound shoulder exercise',
        instructions: 'Press barbell overhead from shoulders to lockout.',
        muscles: [
          { name: 'shoulders', primary: true },
          { name: 'triceps', primary: false },
        ],
      },
      {
        name: 'Barbell Row',
        exerciseType: ExerciseType.strength,
        description: 'Compound back exercise',
        instructions: 'Bend over, row barbell to lower chest.',
        muscles: [
          { name: 'back', primary: true },
          { name: 'biceps', primary: false },
        ],
      },
      {
        name: 'Pull-Up',
        exerciseType: ExerciseType.strength,
        description: 'Upper body pulling exercise',
        instructions: 'Hang from bar, pull chin above bar.',
        muscles: [
          { name: 'back', primary: true },
          { name: 'biceps', primary: false },
        ],
      },
      {
        name: 'Bicep Curl',
        exerciseType: ExerciseType.strength,
        description: 'Isolation bicep exercise',
        instructions: 'Curl dumbbells from full extension to shoulder.',
        muscles: [{ name: 'biceps', primary: true }],
      },
      {
        name: 'Tricep Pushdown',
        exerciseType: ExerciseType.strength,
        description: 'Isolation tricep exercise',
        instructions: 'Push cable attachment down, fully extend elbows.',
        muscles: [{ name: 'triceps', primary: true }],
      },
      {
        name: 'Running',
        exerciseType: ExerciseType.cardio,
        description: 'Cardiovascular exercise',
        instructions: 'Run at chosen pace and distance.',
        muscles: [
          { name: 'quadriceps', primary: true },
          { name: 'calves', primary: false },
        ],
      },
      {
        name: 'Plank',
        exerciseType: ExerciseType.stretching,
        description: 'Core stability exercise',
        instructions: 'Hold forearm plank position, keep body straight.',
        muscles: [{ name: 'core', primary: true }],
      },
    ];

    const exercises: Record<string, string> = {};
    for (const ex of exerciseData) {
      const created = await tx.exercise.create({
        data: {
          name: ex.name,
          exerciseType: ex.exerciseType,
          description: ex.description,
          instructions: ex.instructions,
          isCustom: false,
          muscleGroups: {
            create: ex.muscles.map((m) => ({
              muscleGroupId: muscleGroups[m.name],
              isPrimary: m.primary,
            })),
          },
        },
      });
      exercises[ex.name] = created.id;
    }

    // ─── Workout Plan (Push/Pull/Legs) ──────────────────────
    await tx.workoutPlan.create({
      data: {
        userId: user.id,
        name: 'Push Pull Legs',
        description: 'Classic 3-day split targeting all major muscle groups',
        isActive: true,
        scheduleType: ScheduleType.weekly,
        planDays: {
          create: [
            {
              dayOfWeek: 1,
              name: 'Push Day',
              sortOrder: 0,
              exercises: {
                create: [
                  {
                    exerciseId: exercises['Barbell Bench Press'],
                    sortOrder: 0,
                    targetSets: 4,
                    targetReps: '8-10',
                  },
                  {
                    exerciseId: exercises['Overhead Press'],
                    sortOrder: 1,
                    targetSets: 3,
                    targetReps: '8-12',
                  },
                  {
                    exerciseId: exercises['Tricep Pushdown'],
                    sortOrder: 2,
                    targetSets: 3,
                    targetReps: '12-15',
                  },
                ],
              },
            },
            {
              dayOfWeek: 3,
              name: 'Pull Day',
              sortOrder: 1,
              exercises: {
                create: [
                  {
                    exerciseId: exercises['Conventional Deadlift'],
                    sortOrder: 0,
                    targetSets: 3,
                    targetReps: '5',
                  },
                  {
                    exerciseId: exercises['Barbell Row'],
                    sortOrder: 1,
                    targetSets: 4,
                    targetReps: '8-10',
                  },
                  {
                    exerciseId: exercises['Pull-Up'],
                    sortOrder: 2,
                    targetSets: 3,
                    targetReps: '6-10',
                  },
                  {
                    exerciseId: exercises['Bicep Curl'],
                    sortOrder: 3,
                    targetSets: 3,
                    targetReps: '10-12',
                  },
                ],
              },
            },
            {
              dayOfWeek: 5,
              name: 'Leg Day',
              sortOrder: 2,
              exercises: {
                create: [
                  {
                    exerciseId: exercises['Barbell Back Squat'],
                    sortOrder: 0,
                    targetSets: 4,
                    targetReps: '6-8',
                  },
                  {
                    exerciseId: exercises['Plank'],
                    sortOrder: 1,
                    targetSets: 3,
                    targetDurationSec: 60,
                  },
                  {
                    exerciseId: exercises['Running'],
                    sortOrder: 2,
                    targetSets: 1,
                    targetDurationSec: 1200,
                    targetDistanceM: 3000,
                  },
                ],
              },
            },
          ],
        },
      },
    });

    // ─── Streak ─────────────────────────────────────────────
    await tx.streak.create({
      data: {
        userId: user.id,
        currentStreak: 5,
        longestStreak: 12,
        lastWorkoutDate: new Date(),
      },
    });

    console.log('Seed completed successfully');
    console.log(
      `Created: 2 users, ${muscleGroupData.length} muscle groups, ${exerciseData.length} exercises, 1 workout plan`,
    );
  });
}

main()
  .catch((e) => {
    console.error('Seed failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
    await pool.end();
  });
