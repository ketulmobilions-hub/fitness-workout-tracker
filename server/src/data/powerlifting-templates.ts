// ─── Types ────────────────────────────────────────────────────────────────────

export interface TemplateExercise {
  exerciseName: string; // must match exercise.name in DB (isCustom: false)
  sortOrder: number;
  targetSets: number;
  targetReps?: string;
  targetWeightPct1rm?: number; // fraction of 1RM, must be 0.025 multiple
  targetRpe?: number; // 0.5 increment (6–10)
  targetDurationSec?: number;
  targetDistanceM?: number;
  notes?: string;
}

export interface TemplateDay {
  dayOfWeek: number; // 0=Sun, 1=Mon, ... 6=Sat
  name: string;
  sortOrder: number;
  exercises: TemplateExercise[];
}

export interface TemplateWeek {
  weekNumber: number;
  days: TemplateDay[];
}

export interface ProgramTemplateSummary {
  id: string;
  name: string;
  description: string;
  weeksCount: number;
  daysPerWeek: number;
  difficulty: 'beginner' | 'intermediate' | 'advanced';
  category: 'powerlifting';
  tags: string[];
}

export interface ProgramTemplate extends ProgramTemplateSummary {
  weeks: TemplateWeek[];
}

// ─── 5/3/1 BBB ────────────────────────────────────────────────────────────────

/**
 * 531 BBB per-wave percentages of 1RM (= TM pct × 0.9, rounded to 0.025 multiples).
 * Week pattern: [set1pct, set2pct, set3pct, set1reps, set2reps, set3reps, isDeload]
 */
interface WaveWeekConfig {
  pct1: number;
  pct2: number;
  pct3: number;
  reps1: string;
  reps2: string;
  reps3: string;
  isDeload: boolean;
}

const BBB_WAVE_WEEKS: WaveWeekConfig[] = [
  // Week 1: 5s week — TM%: 65/75/85 → ×0.9 = 58.5/67.5/76.5 → rounded to 0.025: 0.575/0.675/0.775
  { pct1: 0.575, pct2: 0.675, pct3: 0.775, reps1: '5', reps2: '5', reps3: '5', isDeload: false },
  // Week 2: 3s week — TM%: 70/80/90 → ×0.9 = 63/72/81 → 0.625/0.725/0.825
  { pct1: 0.625, pct2: 0.725, pct3: 0.825, reps1: '3', reps2: '3', reps3: '3', isDeload: false },
  // Week 3: 1s week — TM%: 75/85/95 → ×0.9 = 67.5/76.5/85.5 → 0.675/0.775/0.850
  { pct1: 0.675, pct2: 0.775, pct3: 0.850, reps1: '5', reps2: '3', reps3: '1', isDeload: false },
  // Week 4: Deload — TM%: 40/50/60 → ×0.9 = 36/45/54 → 0.350/0.450/0.550
  { pct1: 0.350, pct2: 0.450, pct3: 0.550, reps1: '5', reps2: '5', reps3: '5', isDeload: true },
];

interface BbbDayConfig {
  dayOfWeek: number;
  name: string;
  mainExercise: string;
  accessories: Array<{ exerciseName: string; targetSets: number; targetReps: string; notes?: string }>;
}

const BBB_DAYS: BbbDayConfig[] = [
  {
    dayOfWeek: 1, // Monday
    name: 'Squat Day',
    mainExercise: 'Low Bar Back Squat',
    accessories: [
      { exerciseName: 'Romanian Deadlift', targetSets: 3, targetReps: '8' },
      { exerciseName: 'Leg Curl', targetSets: 3, targetReps: '12' },
    ],
  },
  {
    dayOfWeek: 2, // Tuesday
    name: 'Bench Day',
    mainExercise: 'Competition Bench Press',
    accessories: [
      { exerciseName: 'Tricep Pushdown', targetSets: 4, targetReps: '12' },
      { exerciseName: 'Face Pull', targetSets: 3, targetReps: '15', notes: 'Shoulder health — never skip' },
    ],
  },
  {
    dayOfWeek: 4, // Thursday
    name: 'Deadlift Day',
    mainExercise: 'Conventional Deadlift',
    accessories: [
      { exerciseName: 'Romanian Deadlift', targetSets: 3, targetReps: '8' },
      { exerciseName: 'Barbell Row', targetSets: 3, targetReps: '8' },
    ],
  },
  {
    dayOfWeek: 5, // Friday
    name: 'Overhead Press Day',
    mainExercise: 'Overhead Press',
    accessories: [
      { exerciseName: 'Barbell Curl', targetSets: 3, targetReps: '10' },
      { exerciseName: 'Face Pull', targetSets: 3, targetReps: '15' },
    ],
  },
];

function buildBbbDay(dayConfig: BbbDayConfig, daySortOrder: number, weekCfg: WaveWeekConfig): TemplateDay {
  const exercises: TemplateExercise[] = [];
  let sortOrder = 0;

  // Warmup ramp (standard 5/3/1 warmup — always at fixed %1RM regardless of wave).
  // TM%: 40/50/60 → ×0.9 → 36%/45%/54% 1RM → nearest 0.025: 0.350/0.450/0.550
  exercises.push({
    exerciseName: dayConfig.mainExercise,
    sortOrder: sortOrder++,
    targetSets: 1,
    targetReps: '5',
    targetWeightPct1rm: 0.350,
    notes: 'Warmup ramp 1 — light',
  });
  exercises.push({
    exerciseName: dayConfig.mainExercise,
    sortOrder: sortOrder++,
    targetSets: 1,
    targetReps: '5',
    targetWeightPct1rm: 0.450,
    notes: 'Warmup ramp 2',
  });
  exercises.push({
    exerciseName: dayConfig.mainExercise,
    sortOrder: sortOrder++,
    targetSets: 1,
    targetReps: '3',
    targetWeightPct1rm: 0.550,
    notes: 'Warmup ramp 3',
  });

  // Working set 1
  exercises.push({
    exerciseName: dayConfig.mainExercise,
    sortOrder: sortOrder++,
    targetSets: 1,
    targetReps: weekCfg.reps1,
    targetWeightPct1rm: weekCfg.pct1,
  });

  // Working set 2
  exercises.push({
    exerciseName: dayConfig.mainExercise,
    sortOrder: sortOrder++,
    targetSets: 1,
    targetReps: weekCfg.reps2,
    targetWeightPct1rm: weekCfg.pct2,
  });

  // Top set (AMRAP on non-deload weeks)
  exercises.push({
    exerciseName: dayConfig.mainExercise,
    sortOrder: sortOrder++,
    targetSets: 1,
    targetReps: weekCfg.reps3,
    targetWeightPct1rm: weekCfg.pct3,
    notes: weekCfg.isDeload ? undefined : 'Top set — AMRAP',
  });

  // BBB accessory work: 5×10 @ 45% 1RM
  exercises.push({
    exerciseName: dayConfig.mainExercise,
    sortOrder: sortOrder++,
    targetSets: 5,
    targetReps: '10',
    targetWeightPct1rm: 0.450,
    notes: 'Boring But Big — 5×10 @ ~45% 1RM',
  });

  // Day-specific accessories
  for (const acc of dayConfig.accessories) {
    exercises.push({
      exerciseName: acc.exerciseName,
      sortOrder: sortOrder++,
      targetSets: acc.targetSets,
      targetReps: acc.targetReps,
      notes: acc.notes,
    });
  }

  return {
    dayOfWeek: dayConfig.dayOfWeek,
    name: dayConfig.name,
    sortOrder: daySortOrder,
    exercises,
  };
}

function buildBbbWeeks(): TemplateWeek[] {
  const weeks: TemplateWeek[] = [];

  // 3 waves of 4 weeks = 12 weeks total
  for (let wave = 0; wave < 3; wave++) {
    for (let waveWeek = 0; waveWeek < 4; waveWeek++) {
      const weekNumber = wave * 4 + waveWeek + 1;
      const weekCfg = BBB_WAVE_WEEKS[waveWeek]!;

      const days: TemplateDay[] = BBB_DAYS.map((dayConfig, dayIndex) =>
        buildBbbDay(dayConfig, dayIndex, weekCfg),
      );

      weeks.push({ weekNumber, days });
    }
  }

  return weeks;
}

// ─── GZCLP ────────────────────────────────────────────────────────────────────

interface GzclpDayTemplate {
  label: string;
  days: Array<{
    dayOfWeek: number;
    name: string;
    exercises: TemplateExercise[];
  }>;
}

const GZCLP_DAY_A: GzclpDayTemplate['days'][number] = {
  dayOfWeek: 1, // Monday
  name: 'Day A — Squat / Bench',
  exercises: [
    {
      exerciseName: 'Low Bar Back Squat',
      sortOrder: 0,
      targetSets: 5,
      targetReps: '3',
      targetWeightPct1rm: 0.800,
      notes: 'T1 — Add weight each session when all reps are completed',
    },
    {
      exerciseName: 'Competition Bench Press',
      sortOrder: 1,
      targetSets: 3,
      targetReps: '10',
      targetWeightPct1rm: 0.550,
      notes: 'T2 — Add weight each session when all reps are completed',
    },
    {
      exerciseName: 'Lat Pulldown',
      sortOrder: 2,
      targetSets: 3,
      targetReps: '15',
      notes: 'T3 — Increase reps or weight each session',
    },
  ],
};

const GZCLP_DAY_B: GzclpDayTemplate['days'][number] = {
  dayOfWeek: 3, // Wednesday
  name: 'Day B — Press / Deadlift',
  exercises: [
    {
      exerciseName: 'Overhead Press',
      sortOrder: 0,
      targetSets: 5,
      targetReps: '3',
      targetWeightPct1rm: 0.800,
      notes: 'T1 — Add weight each session when all reps are completed',
    },
    {
      exerciseName: 'Conventional Deadlift',
      sortOrder: 1,
      targetSets: 1,
      targetReps: '5',
      targetWeightPct1rm: 0.800,
      notes: 'T2 — 1×5 for deadlift. Add weight each session when completed',
    },
    {
      exerciseName: 'Barbell Row',
      sortOrder: 2,
      targetSets: 3,
      targetReps: '15',
      notes: 'T3 — Increase reps or weight each session',
    },
  ],
};

const GZCLP_DAY_C: GzclpDayTemplate['days'][number] = {
  dayOfWeek: 5, // Friday
  name: 'Day C — Squat / Press',
  exercises: [
    {
      exerciseName: 'Low Bar Back Squat',
      sortOrder: 0,
      targetSets: 5,
      targetReps: '3',
      targetWeightPct1rm: 0.800,
      notes: 'T1 — Add weight each session when all reps are completed',
    },
    {
      exerciseName: 'Overhead Press',
      sortOrder: 1,
      targetSets: 3,
      targetReps: '10',
      targetWeightPct1rm: 0.550,
      notes: 'T2 — Add weight each session when all reps are completed',
    },
    {
      exerciseName: 'Lat Pulldown',
      sortOrder: 2,
      targetSets: 3,
      targetReps: '15',
      notes: 'T3 — Increase reps or weight each session',
    },
  ],
};

function buildGzclpWeeks(): TemplateWeek[] {
  const weeks: TemplateWeek[] = [];

  // 8 weeks: alternating ABA / BAB pattern
  // Week 1: ABA (Mon=A, Wed=B, Fri=A)
  // Week 2: BAB (Mon=B, Wed=A, Fri=B)
  // Repeat for weeks 3–8
  for (let week = 1; week <= 8; week++) {
    const isAbaWeek = week % 2 === 1;

    let monday: GzclpDayTemplate['days'][number];
    let wednesday: GzclpDayTemplate['days'][number];
    let friday: GzclpDayTemplate['days'][number];

    if (isAbaWeek) {
      // ABA: Mon=A, Wed=B, Fri=C (C is the "second A day" variant with OHP as T2)
      monday = { ...GZCLP_DAY_A, dayOfWeek: 1 };
      wednesday = { ...GZCLP_DAY_B, dayOfWeek: 3 };
      friday = { ...GZCLP_DAY_C, dayOfWeek: 5 };
    } else {
      // BAB: Mon=B variant, Wed=A variant, Fri=B variant
      // Shift day names but keep exercises, update dayOfWeek
      monday = { ...GZCLP_DAY_B, dayOfWeek: 1, name: 'Day B — Press / Deadlift' };
      wednesday = { ...GZCLP_DAY_A, dayOfWeek: 3, name: 'Day A — Squat / Bench' };
      friday = { ...GZCLP_DAY_B, dayOfWeek: 5, name: 'Day B — Press / Deadlift' };
    }

    weeks.push({
      weekNumber: week,
      days: [monday, wednesday, friday].map((d, i) => ({ ...d, sortOrder: i })),
    });
  }

  return weeks;
}

// ─── The Bridge 1.0 ───────────────────────────────────────────────────────────

interface BridgeWeekConfig {
  weekNumber: number;
  mainRpe: number;
  mainReps: number;
  isDeload: boolean;
}

const BRIDGE_WEEK_CONFIGS: BridgeWeekConfig[] = [
  { weekNumber: 1, mainRpe: 8.0, mainReps: 5, isDeload: false },
  { weekNumber: 2, mainRpe: 8.5, mainReps: 5, isDeload: false },
  { weekNumber: 3, mainRpe: 8.5, mainReps: 4, isDeload: false },
  { weekNumber: 4, mainRpe: 9.0, mainReps: 4, isDeload: false },
  { weekNumber: 5, mainRpe: 9.0, mainReps: 3, isDeload: false },
  { weekNumber: 6, mainRpe: 9.5, mainReps: 3, isDeload: false },
  { weekNumber: 7, mainRpe: 9.0, mainReps: 2, isDeload: false },
  { weekNumber: 8, mainRpe: 7.0, mainReps: 5, isDeload: true },
];

function buildBridgeDay1(cfg: BridgeWeekConfig, sortOrder: number): TemplateDay {
  const repsStr = String(cfg.mainReps);
  const accRpe = cfg.isDeload ? 6.0 : 7.0;
  // Back-off sets use mainRpe − 1 so the top set is the true maximal effort.
  const backOffRpe = cfg.isDeload ? 6.0 : Math.max(6.0, cfg.mainRpe - 1.0);

  return {
    dayOfWeek: 1, // Monday
    name: 'Day 1 — Squat Focus',
    sortOrder,
    exercises: [
      // 2 back-off sets then 1 top set
      {
        exerciseName: 'Low Bar Back Squat',
        sortOrder: 0,
        targetSets: 2,
        targetReps: repsStr,
        targetRpe: backOffRpe,
        notes: 'Back-off sets',
      },
      {
        exerciseName: 'Low Bar Back Squat',
        sortOrder: 1,
        targetSets: 1,
        targetReps: repsStr,
        targetRpe: cfg.mainRpe,
        notes: 'Top set',
      },
      {
        exerciseName: 'Pause Squat',
        sortOrder: 2,
        targetSets: 3,
        targetReps: '3',
        targetRpe: accRpe,
        notes: '2-second pause in the hole',
      },
      {
        exerciseName: 'Romanian Deadlift',
        sortOrder: 3,
        targetSets: 3,
        targetReps: '8',
        targetRpe: accRpe,
      },
      {
        exerciseName: 'Hanging Leg Raise',
        sortOrder: 4,
        targetSets: 3,
        targetReps: '10',
        notes: 'Core work',
      },
    ],
  };
}

function buildBridgeDay2(cfg: BridgeWeekConfig, sortOrder: number): TemplateDay {
  const repsStr = String(cfg.mainReps);
  const accRpe = cfg.isDeload ? 6.0 : 7.0;
  const backOffRpe = cfg.isDeload ? 6.0 : Math.max(6.0, cfg.mainRpe - 1.0);

  return {
    dayOfWeek: 2, // Tuesday
    name: 'Day 2 — Bench Focus',
    sortOrder,
    exercises: [
      {
        exerciseName: 'Competition Bench Press',
        sortOrder: 0,
        targetSets: 2,
        targetReps: repsStr,
        targetRpe: backOffRpe,
        notes: 'Back-off sets',
      },
      {
        exerciseName: 'Competition Bench Press',
        sortOrder: 1,
        targetSets: 1,
        targetReps: repsStr,
        targetRpe: cfg.mainRpe,
        notes: 'Top set',
      },
      {
        exerciseName: 'Pause Bench Press',
        sortOrder: 2,
        targetSets: 3,
        targetReps: '3',
        targetRpe: accRpe,
        notes: '2-second pause on chest',
      },
      {
        exerciseName: 'Barbell Row',
        sortOrder: 3,
        targetSets: 3,
        targetReps: '8',
        targetRpe: accRpe,
      },
      {
        exerciseName: 'Face Pull',
        sortOrder: 4,
        targetSets: 3,
        targetReps: '15',
        notes: 'Shoulder health — never skip',
      },
    ],
  };
}

function buildBridgeDay3(cfg: BridgeWeekConfig, sortOrder: number): TemplateDay {
  const repsStr = String(cfg.mainReps);
  const accRpe = cfg.isDeload ? 6.0 : 7.0;
  const backOffRpe = cfg.isDeload ? 6.0 : Math.max(6.0, cfg.mainRpe - 1.0);

  return {
    dayOfWeek: 4, // Thursday
    name: 'Day 3 — Deadlift Focus',
    sortOrder,
    exercises: [
      {
        exerciseName: 'Conventional Deadlift',
        sortOrder: 0,
        targetSets: 2,
        targetReps: repsStr,
        targetRpe: backOffRpe,
        notes: 'Back-off sets',
      },
      {
        exerciseName: 'Conventional Deadlift',
        sortOrder: 1,
        targetSets: 1,
        targetReps: repsStr,
        targetRpe: cfg.mainRpe,
        notes: 'Top set',
      },
      {
        exerciseName: 'Good Morning',
        sortOrder: 2,
        targetSets: 3,
        targetReps: '8',
        targetRpe: accRpe,
        notes: 'Keep back flat, slight knee bend',
      },
      {
        exerciseName: 'Plank',
        sortOrder: 3,
        targetSets: 3,
        targetReps: '1',
        notes: '30 second hold',
      },
    ],
  };
}

function buildBridgeDay4(cfg: BridgeWeekConfig, sortOrder: number): TemplateDay {
  const accRpe = cfg.isDeload ? 6.0 : 7.0;

  return {
    dayOfWeek: 5, // Friday
    name: 'Day 4 — OHP & Squat Variation',
    sortOrder,
    exercises: [
      {
        exerciseName: 'Overhead Press',
        sortOrder: 0,
        targetSets: 3,
        targetReps: '8',
        targetRpe: accRpe,
        notes: 'Strict press — no leg drive',
      },
      {
        exerciseName: 'Low Bar Back Squat',
        sortOrder: 1,
        targetSets: 2,
        targetReps: '5',
        targetRpe: accRpe,
        notes: 'Lighter squat — focus on technique',
      },
      {
        exerciseName: 'Chin-Up',
        sortOrder: 2,
        targetSets: 3,
        targetReps: '8',
        notes: 'Add weight when sets feel easy',
      },
      {
        exerciseName: 'Back Extension',
        sortOrder: 3,
        targetSets: 3,
        targetReps: '10',
        notes: 'Posterior chain accessory',
      },
    ],
  };
}

function buildBridgeWeeks(): TemplateWeek[] {
  return BRIDGE_WEEK_CONFIGS.map((cfg) => ({
    weekNumber: cfg.weekNumber,
    days: [
      buildBridgeDay1(cfg, 0),
      buildBridgeDay2(cfg, 1),
      buildBridgeDay3(cfg, 2),
      buildBridgeDay4(cfg, 3),
    ],
  }));
}

// ─── Template Registry ────────────────────────────────────────────────────────

export const PROGRAM_TEMPLATES: ProgramTemplate[] = [
  {
    id: '531-bbb',
    name: "5/3/1 Boring But Big",
    description:
      "Jim Wendler's 5/3/1 program with Boring But Big (BBB) accessory work. A classic intermediate strength-hypertrophy program built around four main lifts (squat, bench, deadlift, OHP) with progressive overload across 3-week waves and deload weeks. The 5×10 BBB sets at 45% 1RM build muscle and work capacity alongside the strength work.",
    weeksCount: 12,
    daysPerWeek: 4,
    difficulty: 'intermediate',
    category: 'powerlifting',
    tags: ['5/3/1', 'strength', 'hypertrophy', 'powerlifting'],
    weeks: buildBbbWeeks(),
  },
  {
    id: 'gzclp',
    name: 'GZCLP',
    description:
      'The GZCLP (Garage Gym Zealot linear progression) is a 3-day beginner strength program based on the GZCL method. It uses a tiered exercise system: T1 movements (5×3) for low-rep strength, T2 movements (3×10) for hypertrophy, and T3 isolation work (3×15). Add weight every session — when you fail to complete all reps, drop to the next progression scheme.',
    weeksCount: 8,
    daysPerWeek: 3,
    difficulty: 'beginner',
    category: 'powerlifting',
    tags: ['linear progression', 'beginner', 'strength', 'full body'],
    weeks: buildGzclpWeeks(),
  },
  {
    id: 'bridge-1',
    name: 'The Bridge 1.0',
    description:
      'The Bridge 1.0 by Barbell Medicine is an intermediate RPE-based powerlifting program. It bridges the gap between novice linear progression and advanced programming through autoregulation using RPE (Rate of Perceived Exertion). The 8-week program progressively increases intensity from RPE 8 to 9.5 before a deload week, featuring competition lifts plus pause variations and targeted accessories.',
    weeksCount: 8,
    daysPerWeek: 4,
    difficulty: 'intermediate',
    category: 'powerlifting',
    tags: ['RPE', 'autoregulation', 'powerlifting', 'Barbell Medicine'],
    weeks: buildBridgeWeeks(),
  },
];
