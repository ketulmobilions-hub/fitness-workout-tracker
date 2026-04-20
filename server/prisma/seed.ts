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
  // Compute hash before transaction (CPU-only work, no DB connection needed)
  // Cost factor matches the auth service (auth.controller.ts uses 12)
  const passwordHash = await bcrypt.hash('password123', 12);

  // Single atomic transaction — wipe everything then re-seed.
  // Keeping delete + insert in one transaction ensures the DB is never left
  // empty: if anything fails, the entire transaction rolls back and the
  // previous data is preserved.
  await prisma.$transaction(
    async (tx) => {
      // ── Cleanup (explicit dependency order) ──────────────
      // All tables are listed explicitly rather than relying on CASCADE so
      // that adding a new table with a FK to User doesn't silently skip cleanup.
      await tx.syncQueue.deleteMany();
      await tx.streakHistory.deleteMany();
      await tx.streak.deleteMany();
      await tx.personalRecord.deleteMany();
      await tx.setLog.deleteMany();
      await tx.exerciseLog.deleteMany();
      await tx.workoutSession.deleteMany();
      await tx.planDayExercise.deleteMany();
      await tx.planDay.deleteMany();
      await tx.workoutPlan.deleteMany();
      await tx.exerciseEquipment.deleteMany();
      await tx.exerciseMuscleGroup.deleteMany();
      await tx.exercise.deleteMany();
      await tx.muscleGroup.deleteMany();
      await tx.equipment.deleteMany();
      await tx.passwordResetToken.deleteMany();
      await tx.refreshToken.deleteMany();
      await tx.user.deleteMany();

      // ─── Users ─────────────────────────────────────────────
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
        { name: 'lats', displayName: 'Lats', bodyRegion: 'upper' },
        { name: 'traps', displayName: 'Traps', bodyRegion: 'upper' },
        { name: 'shoulders', displayName: 'Shoulders', bodyRegion: 'upper' },
        { name: 'biceps', displayName: 'Biceps', bodyRegion: 'upper' },
        { name: 'triceps', displayName: 'Triceps', bodyRegion: 'upper' },
        { name: 'forearms', displayName: 'Forearms', bodyRegion: 'upper' },
        { name: 'quadriceps', displayName: 'Quadriceps', bodyRegion: 'lower' },
        { name: 'hamstrings', displayName: 'Hamstrings', bodyRegion: 'lower' },
        { name: 'glutes', displayName: 'Glutes', bodyRegion: 'lower' },
        { name: 'calves', displayName: 'Calves', bodyRegion: 'lower' },
        { name: 'hip_flexors', displayName: 'Hip Flexors', bodyRegion: 'lower' },
        { name: 'adductors', displayName: 'Adductors', bodyRegion: 'lower' },
        { name: 'core', displayName: 'Core', bodyRegion: 'core' },
        { name: 'abs', displayName: 'Abs', bodyRegion: 'core' },
        { name: 'lower_back', displayName: 'Lower Back', bodyRegion: 'core' },
      ];

      const mg: Record<string, string> = {};
      for (const data of muscleGroupData) {
        const created = await tx.muscleGroup.create({ data });
        mg[data.name] = created.id;
      }

      // ─── Equipment ──────────────────────────────────────────
      const equipmentData = [
        { name: 'barbell', displayName: 'Barbell' },
        { name: 'dumbbell', displayName: 'Dumbbell' },
        { name: 'cable_machine', displayName: 'Cable Machine' },
        { name: 'bodyweight', displayName: 'Bodyweight' },
        { name: 'kettlebell', displayName: 'Kettlebell' },
        { name: 'resistance_band', displayName: 'Resistance Band' },
        { name: 'pull_up_bar', displayName: 'Pull-Up Bar' },
        { name: 'bench', displayName: 'Bench' },
        { name: 'treadmill', displayName: 'Treadmill' },
        { name: 'stationary_bike', displayName: 'Stationary Bike' },
        { name: 'rowing_machine', displayName: 'Rowing Machine' },
        { name: 'jump_rope', displayName: 'Jump Rope' },
        { name: 'leg_press_machine', displayName: 'Leg Press Machine' },
        { name: 'smith_machine', displayName: 'Smith Machine' },
        { name: 'pec_deck_machine', displayName: 'Pec Deck Machine' },
        { name: 'leg_extension_machine', displayName: 'Leg Extension Machine' },
        { name: 'leg_curl_machine', displayName: 'Leg Curl Machine' },
        { name: 'calf_raise_machine', displayName: 'Calf Raise Machine' },
        { name: 'hack_squat_machine', displayName: 'Hack Squat Machine' },
        { name: 'stair_climber', displayName: 'Stair Climber' },
        { name: 'bicycle', displayName: 'Bicycle' },
        { name: 'foam_roller', displayName: 'Foam Roller' },
        { name: 'ab_wheel', displayName: 'Ab Wheel' },
        { name: 'battle_ropes', displayName: 'Battle Ropes' },
        { name: 'sled', displayName: 'Sled' },
        { name: 'box', displayName: 'Plyo Box' },
        { name: 'yoga_mat', displayName: 'Yoga Mat' },
        { name: 'pool', displayName: 'Pool' },
        { name: 'elliptical', displayName: 'Elliptical Machine' },
      ];

      const eq: Record<string, string> = {};
      for (const data of equipmentData) {
        const created = await tx.equipment.create({ data });
        eq[data.name] = created.id;
      }

      // ─── Exercises ──────────────────────────────────────────
      type ExerciseDef = {
        name: string;
        exerciseType: ExerciseType;
        description: string;
        instructions: string;
        muscles: { name: string; primary: boolean }[];
        equipment: string[];
      };

      // Notes on ExerciseType classification:
      //   - Plank, Kettlebell Swing, Battle Ropes, Box Jump, Sled Push are
      //     classified as `strength` (loaded/resistance-based movements).
      //     They could be argued as cardio, but the schema has no `isometric`
      //     or `conditioning` type, and `strength` is the closest fit.
      //   - All stretching/mobility work uses ExerciseType.stretching.

      const exerciseData: ExerciseDef[] = [
        // ── Chest (Strength) ──────────────────────────────────
        {
          name: 'Barbell Bench Press',
          exerciseType: ExerciseType.strength,
          description: 'Classic horizontal press that targets the chest with a barbell.',
          instructions:
            'Lie flat on a bench with a shoulder-width grip. Unrack the bar, lower it to your mid-chest under control, then press back to full extension. Keep your feet flat, back slightly arched, and shoulders retracted throughout.',
          muscles: [
            { name: 'chest', primary: true },
            { name: 'triceps', primary: false },
            { name: 'shoulders', primary: false },
          ],
          equipment: ['barbell', 'bench'],
        },
        {
          name: 'Incline Dumbbell Press',
          exerciseType: ExerciseType.strength,
          description: 'Upper-chest press performed on an inclined bench with dumbbells.',
          instructions:
            'Set bench to 30–45°. Hold a dumbbell in each hand at shoulder level, palms facing forward. Press up and slightly inward until arms are extended, then lower slowly.',
          muscles: [
            { name: 'chest', primary: true },
            { name: 'shoulders', primary: false },
            { name: 'triceps', primary: false },
          ],
          equipment: ['dumbbell', 'bench'],
        },
        {
          name: 'Decline Barbell Press',
          exerciseType: ExerciseType.strength,
          description: 'Lower-chest emphasis press on a decline bench.',
          instructions:
            'Secure feet on a decline bench. Grip bar slightly wider than shoulder-width. Lower bar to lower chest, press back to lockout. Maintain shoulder retraction.',
          muscles: [
            { name: 'chest', primary: true },
            { name: 'triceps', primary: false },
          ],
          equipment: ['barbell', 'bench'],
        },
        {
          name: 'Dumbbell Fly',
          exerciseType: ExerciseType.strength,
          description: 'Chest isolation exercise that stretches the pec fibers.',
          instructions:
            'Lie flat on bench with a dumbbell in each hand. With a slight bend in the elbow, open arms wide in an arc until you feel a chest stretch, then squeeze back to the starting position.',
          muscles: [
            { name: 'chest', primary: true },
            { name: 'shoulders', primary: false },
          ],
          equipment: ['dumbbell', 'bench'],
        },
        {
          name: 'Cable Crossover',
          exerciseType: ExerciseType.strength,
          description: 'Cable fly variation that maintains tension throughout the range of motion.',
          instructions:
            'Stand between two high cable pulleys. Grab each handle and step forward. With a slight torso lean, bring hands together in front of your chest in an arc, then return slowly.',
          muscles: [
            { name: 'chest', primary: true },
            { name: 'shoulders', primary: false },
          ],
          equipment: ['cable_machine'],
        },
        {
          name: 'Push-Up',
          exerciseType: ExerciseType.strength,
          description: 'Foundational bodyweight chest press requiring no equipment.',
          instructions:
            'Place hands slightly wider than shoulder-width on the floor. Keep body in a straight line from head to heels. Lower chest toward the floor by bending elbows, then push back up.',
          muscles: [
            { name: 'chest', primary: true },
            { name: 'triceps', primary: false },
            { name: 'shoulders', primary: false },
            { name: 'core', primary: false },
          ],
          equipment: ['bodyweight'],
        },
        {
          name: 'Chest Dip',
          exerciseType: ExerciseType.strength,
          description: 'Compound lower-chest and tricep movement on parallel bars.',
          instructions:
            'Grip parallel bars and support your bodyweight. Lean slightly forward, bend elbows and lower until upper arms are parallel to ground, then press back up.',
          muscles: [
            { name: 'chest', primary: true },
            { name: 'triceps', primary: false },
            { name: 'shoulders', primary: false },
          ],
          equipment: ['bodyweight'],
        },
        {
          name: 'Pec Deck Machine',
          exerciseType: ExerciseType.strength,
          description: 'Machine isolation exercise for the chest with a guided arc movement.',
          instructions:
            'Sit at the machine with forearms on the padded arms. Squeeze chest to bring the pads together in front of you, hold briefly, then release under control.',
          muscles: [{ name: 'chest', primary: true }],
          equipment: ['pec_deck_machine'],
        },

        // ── Back (Strength) ───────────────────────────────────
        {
          name: 'Barbell Row',
          exerciseType: ExerciseType.strength,
          description: 'Compound back exercise performed with a barbell in a bent-over position.',
          instructions:
            'Hinge at hips until torso is roughly parallel to the floor, grip bar just outside hip width. Row bar toward your lower chest, leading with elbows. Lower under control.',
          muscles: [
            { name: 'back', primary: true },
            { name: 'lats', primary: true },
            { name: 'biceps', primary: false },
            { name: 'traps', primary: false },
          ],
          equipment: ['barbell'],
        },
        {
          name: 'Pull-Up',
          exerciseType: ExerciseType.strength,
          description: 'Upper body pulling movement using a pull-up bar.',
          instructions:
            'Hang from a pull-up bar with an overhand grip slightly wider than shoulder-width. Pull yourself up until chin clears the bar, then lower fully.',
          muscles: [
            { name: 'lats', primary: true },
            { name: 'biceps', primary: false },
            { name: 'traps', primary: false },
            { name: 'core', primary: false },
          ],
          equipment: ['pull_up_bar', 'bodyweight'],
        },
        {
          name: 'Chin-Up',
          exerciseType: ExerciseType.strength,
          description: 'Underhand-grip pull-up that increases bicep involvement.',
          instructions:
            'Hang from bar with an underhand (supinated) shoulder-width grip. Pull yourself up until chin clears the bar, squeezing biceps at the top.',
          muscles: [
            { name: 'lats', primary: true },
            { name: 'biceps', primary: true },
            { name: 'back', primary: false },
          ],
          equipment: ['pull_up_bar', 'bodyweight'],
        },
        {
          name: 'Lat Pulldown',
          exerciseType: ExerciseType.strength,
          description: 'Cable machine version of the pull-up for lat width.',
          instructions:
            'Sit at a lat pulldown machine and grab the bar wide. Lean slightly back, pull the bar down to your upper chest, squeezing your lats, then let the bar rise under control.',
          muscles: [
            { name: 'lats', primary: true },
            { name: 'biceps', primary: false },
            { name: 'back', primary: false },
          ],
          equipment: ['cable_machine'],
        },
        {
          name: 'Seated Cable Row',
          exerciseType: ExerciseType.strength,
          description: 'Horizontal cable pull targeting the mid-back.',
          instructions:
            'Sit at a cable row station, feet on pads. Row the handle toward your lower abdomen, driving elbows back. Pause, then extend arms fully under control.',
          muscles: [
            { name: 'back', primary: true },
            { name: 'lats', primary: false },
            { name: 'biceps', primary: false },
            { name: 'traps', primary: false },
          ],
          equipment: ['cable_machine'],
        },
        {
          name: 'Dumbbell Row',
          exerciseType: ExerciseType.strength,
          description: 'Single-arm back row allowing full range of motion.',
          instructions:
            'Place one hand and knee on a bench for support. Hold a dumbbell in the other hand, let it hang, then row it to your hip, keeping elbow close to your body.',
          muscles: [
            { name: 'lats', primary: true },
            { name: 'back', primary: true },
            { name: 'biceps', primary: false },
          ],
          equipment: ['dumbbell', 'bench'],
        },
        {
          name: 'T-Bar Row',
          exerciseType: ExerciseType.strength,
          description: 'Compound back exercise using a T-bar or landmine attachment.',
          instructions:
            'Straddle a barbell loaded at one end. Grip the handle or bar, hinge forward, and row the weight toward your chest. Keep back flat and core engaged.',
          muscles: [
            { name: 'back', primary: true },
            { name: 'lats', primary: true },
            { name: 'biceps', primary: false },
            { name: 'traps', primary: false },
          ],
          equipment: ['barbell'],
        },
        {
          name: 'Face Pull',
          exerciseType: ExerciseType.strength,
          description: 'Cable exercise for rear delts, traps, and external rotators.',
          instructions:
            'Set a cable pulley to upper chest height with a rope attachment. Pull the rope toward your face, pulling the ends apart as it reaches you. Elbows stay high throughout.',
          muscles: [
            { name: 'traps', primary: true },
            { name: 'shoulders', primary: true },
            { name: 'back', primary: false },
          ],
          equipment: ['cable_machine'],
        },
        {
          name: 'Straight Arm Pulldown',
          exerciseType: ExerciseType.strength,
          description: 'Isolation exercise for the lats with arms kept straight.',
          instructions:
            'Stand at a cable machine with a bar attachment set high. With arms extended and a slight elbow bend, pull the bar down in an arc to your thighs. Squeeze lats at the bottom.',
          muscles: [
            { name: 'lats', primary: true },
            { name: 'core', primary: false },
          ],
          equipment: ['cable_machine'],
        },
        {
          name: 'Rack Pull',
          exerciseType: ExerciseType.strength,
          description: 'Partial range deadlift from knee height to lockout for upper back.',
          instructions:
            'Set barbell in a rack at knee height. Stand with a hip-width stance, grip bar, and drive hips forward to lock out. Focus on squeezing traps at the top.',
          muscles: [
            { name: 'traps', primary: true },
            { name: 'back', primary: true },
            { name: 'glutes', primary: false },
            { name: 'lower_back', primary: false },
          ],
          equipment: ['barbell'],
        },

        // ── Shoulders (Strength) ──────────────────────────────
        {
          name: 'Overhead Press',
          exerciseType: ExerciseType.strength,
          description: 'Compound barbell press overhead for shoulder mass and strength.',
          instructions:
            'Stand with a barbell racked at shoulder height. Grip just outside shoulder width, unrack and press overhead to full lockout. Lower to clavicle level under control.',
          muscles: [
            { name: 'shoulders', primary: true },
            { name: 'triceps', primary: false },
            { name: 'traps', primary: false },
            { name: 'core', primary: false },
          ],
          equipment: ['barbell'],
        },
        {
          name: 'Dumbbell Lateral Raise',
          exerciseType: ExerciseType.strength,
          description: 'Isolation movement to build lateral (side) deltoid width.',
          instructions:
            'Stand holding dumbbells at your sides. Raise arms out to the sides until they reach shoulder height, then lower under control. Maintain a slight elbow bend throughout.',
          muscles: [{ name: 'shoulders', primary: true }],
          equipment: ['dumbbell'],
        },
        {
          name: 'Dumbbell Front Raise',
          exerciseType: ExerciseType.strength,
          description: 'Targets the anterior (front) deltoid.',
          instructions:
            'Stand holding dumbbells in front of your thighs. Raise one or both arms forward to shoulder height with elbows slightly bent, then lower slowly.',
          muscles: [
            { name: 'shoulders', primary: true },
            { name: 'chest', primary: false },
          ],
          equipment: ['dumbbell'],
        },
        {
          name: 'Arnold Press',
          exerciseType: ExerciseType.strength,
          description: 'Dumbbell shoulder press with a rotation to hit all three delt heads.',
          instructions:
            'Sit holding dumbbells at chin height with palms facing you. As you press overhead, rotate palms forward. Reverse the rotation as you lower back to the start.',
          muscles: [
            { name: 'shoulders', primary: true },
            { name: 'triceps', primary: false },
          ],
          equipment: ['dumbbell', 'bench'],
        },
        {
          name: 'Rear Delt Fly',
          exerciseType: ExerciseType.strength,
          description: 'Isolation exercise for the posterior deltoid and upper back.',
          instructions:
            'Bend forward at the hips or lie chest-down on an incline bench. Hold dumbbells hanging below, then raise them out to the sides until arms are parallel to the ground.',
          muscles: [
            { name: 'shoulders', primary: true },
            { name: 'traps', primary: false },
            { name: 'back', primary: false },
          ],
          equipment: ['dumbbell'],
        },
        {
          name: 'Upright Row',
          exerciseType: ExerciseType.strength,
          description: 'Compound shoulder and trap movement with a barbell or dumbbells.',
          instructions:
            'Hold barbell with a narrow overhand grip in front of your thighs. Pull bar straight up toward your chin, leading with elbows. Lower under control.',
          muscles: [
            { name: 'shoulders', primary: true },
            { name: 'traps', primary: true },
            { name: 'biceps', primary: false },
          ],
          equipment: ['barbell'],
        },
        {
          name: 'Cable Lateral Raise',
          exerciseType: ExerciseType.strength,
          description: 'Cable version of the lateral raise for continuous tension on delts.',
          instructions:
            'Stand beside a low cable pulley and grip the handle with the far hand. Raise arm out to the side to shoulder height, then lower under control.',
          muscles: [{ name: 'shoulders', primary: true }],
          equipment: ['cable_machine'],
        },

        // ── Biceps (Strength) ─────────────────────────────────
        {
          name: 'Barbell Curl',
          exerciseType: ExerciseType.strength,
          description: 'Classic barbell curl for overall bicep mass.',
          instructions:
            'Stand holding a barbell with a shoulder-width underhand grip. Curl the bar toward your shoulders, keeping elbows at your sides. Lower fully to stretch the bicep.',
          muscles: [
            { name: 'biceps', primary: true },
            { name: 'forearms', primary: false },
          ],
          equipment: ['barbell'],
        },
        {
          name: 'Dumbbell Curl',
          exerciseType: ExerciseType.strength,
          description: 'Standard dumbbell curl for bicep development with free range of rotation.',
          instructions:
            'Stand with a dumbbell in each hand, palms forward. Curl both dumbbells toward your shoulders, then lower under control.',
          muscles: [
            { name: 'biceps', primary: true },
            { name: 'forearms', primary: false },
          ],
          equipment: ['dumbbell'],
        },
        {
          name: 'Hammer Curl',
          exerciseType: ExerciseType.strength,
          description: 'Neutral-grip curl targeting the brachialis and brachioradialis.',
          instructions:
            'Hold dumbbells at your sides with palms facing each other (neutral grip). Curl both dumbbells toward your shoulders without rotating the wrist.',
          muscles: [
            { name: 'biceps', primary: true },
            { name: 'forearms', primary: true },
          ],
          equipment: ['dumbbell'],
        },
        {
          name: 'Preacher Curl',
          exerciseType: ExerciseType.strength,
          description: 'Curl variation on a preacher bench that eliminates body swing.',
          instructions:
            'Rest upper arms on a preacher bench pad. Hold a barbell or EZ bar with an underhand grip. Curl the weight up until fully contracted, then lower slowly to full extension.',
          muscles: [{ name: 'biceps', primary: true }],
          equipment: ['barbell', 'bench'],
        },
        {
          name: 'Cable Curl',
          exerciseType: ExerciseType.strength,
          description: 'Low cable curl that maintains constant tension throughout.',
          instructions:
            'Stand facing a low cable pulley with a straight bar attachment. Curl the bar up toward your chin, keeping elbows still, then lower under control.',
          muscles: [{ name: 'biceps', primary: true }],
          equipment: ['cable_machine'],
        },

        // ── Triceps (Strength) ────────────────────────────────
        {
          name: 'Tricep Pushdown',
          exerciseType: ExerciseType.strength,
          description: 'Cable isolation exercise for the triceps using a rope or bar.',
          instructions:
            'Stand at a high cable pulley with a rope or bar attachment. Keep elbows at your sides and press the attachment down until arms are fully extended, then let it rise under control.',
          muscles: [{ name: 'triceps', primary: true }],
          equipment: ['cable_machine'],
        },
        {
          name: 'Skull Crusher',
          exerciseType: ExerciseType.strength,
          description: 'Lying barbell tricep extension — great for the long head.',
          instructions:
            'Lie on a flat bench with an EZ bar or barbell. Lower the bar toward your forehead by bending only the elbows, then extend back to lockout.',
          muscles: [{ name: 'triceps', primary: true }],
          equipment: ['barbell', 'bench'],
        },
        {
          name: 'Overhead Tricep Extension',
          exerciseType: ExerciseType.strength,
          description: 'Dumbbell tricep extension overhead for long head emphasis.',
          instructions:
            "Hold one dumbbell with both hands overhead at arm's length. Bend elbows to lower the weight behind your head, then extend back up. Keep upper arms stationary.",
          muscles: [{ name: 'triceps', primary: true }],
          equipment: ['dumbbell'],
        },
        {
          name: 'Diamond Push-Up',
          exerciseType: ExerciseType.strength,
          description: 'Bodyweight push-up variation with hands close together for tricep focus.',
          instructions:
            'Assume a push-up position with thumbs and index fingers touching to form a diamond shape. Lower chest to hands, then press back up keeping elbows tracking straight back.',
          muscles: [
            { name: 'triceps', primary: true },
            { name: 'chest', primary: false },
          ],
          equipment: ['bodyweight'],
        },
        {
          name: 'Tricep Dip',
          exerciseType: ExerciseType.strength,
          description: 'Bodyweight dip with upright torso to target the triceps.',
          instructions:
            'Support yourself on parallel bars. Keep torso upright, then lower yourself by bending elbows until upper arms are parallel to the floor. Press back to full extension.',
          muscles: [
            { name: 'triceps', primary: true },
            { name: 'chest', primary: false },
            { name: 'shoulders', primary: false },
          ],
          equipment: ['bodyweight'],
        },

        // ── Legs (Strength) ───────────────────────────────────
        {
          name: 'Barbell Back Squat',
          exerciseType: ExerciseType.strength,
          description: 'King of lower body exercises — compound quad, glute, and hamstring movement.',
          instructions:
            'Place bar on upper traps, step back and set a shoulder-width stance. Break at hips and knees simultaneously, descend until thighs are at least parallel to the floor, then drive back up.',
          muscles: [
            { name: 'quadriceps', primary: true },
            { name: 'glutes', primary: true },
            { name: 'hamstrings', primary: false },
            { name: 'core', primary: false },
          ],
          equipment: ['barbell'],
        },
        {
          name: 'Conventional Deadlift',
          exerciseType: ExerciseType.strength,
          description: 'Full-body pull from the floor targeting the entire posterior chain.',
          instructions:
            'Stand with feet hip-width, toes under bar. Grip just outside legs, brace core, and drive through the floor while pushing hips forward to lockout. Lower with control.',
          muscles: [
            { name: 'hamstrings', primary: true },
            { name: 'glutes', primary: true },
            { name: 'lower_back', primary: true },
            { name: 'traps', primary: false },
            { name: 'forearms', primary: false },
          ],
          equipment: ['barbell'],
        },
        {
          name: 'Romanian Deadlift',
          exerciseType: ExerciseType.strength,
          description: 'Hip-hinge movement with slight knee bend that isolates the hamstrings and glutes.',
          instructions:
            'Stand holding a barbell at hip height. Hinge at the hips, pushing them back as you lower the bar along your legs until you feel a strong hamstring stretch. Drive hips forward to return.',
          muscles: [
            { name: 'hamstrings', primary: true },
            { name: 'glutes', primary: true },
            { name: 'lower_back', primary: false },
          ],
          equipment: ['barbell'],
        },
        {
          name: 'Sumo Deadlift',
          exerciseType: ExerciseType.strength,
          description: 'Wide-stance deadlift variant with more inner thigh and glute involvement.',
          instructions:
            'Take a wide stance with toes pointed out. Grip the bar with a narrow, inside-the-legs grip. Drive knees out and hips toward the bar as you pull to lockout.',
          muscles: [
            { name: 'glutes', primary: true },
            { name: 'adductors', primary: true },
            { name: 'hamstrings', primary: false },
            { name: 'lower_back', primary: false },
          ],
          equipment: ['barbell'],
        },
        {
          name: 'Leg Press',
          exerciseType: ExerciseType.strength,
          description: 'Machine quad-dominant press allowing heavy loading without spinal compression.',
          instructions:
            'Sit in the leg press machine with feet shoulder-width on the platform. Unlock the safety, lower the sled by bending knees to 90°, then press back to near-lockout.',
          muscles: [
            { name: 'quadriceps', primary: true },
            { name: 'glutes', primary: false },
            { name: 'hamstrings', primary: false },
          ],
          equipment: ['leg_press_machine'],
        },
        {
          name: 'Bulgarian Split Squat',
          exerciseType: ExerciseType.strength,
          description: 'Single-leg squat with rear foot elevated — excellent for quads and glutes.',
          instructions:
            'Place rear foot on a bench, step front foot forward. Lower back knee toward the floor, keeping front shin vertical. Drive through front heel to return.',
          muscles: [
            { name: 'quadriceps', primary: true },
            { name: 'glutes', primary: true },
            { name: 'hamstrings', primary: false },
          ],
          equipment: ['dumbbell', 'bench'],
        },
        {
          name: 'Leg Extension',
          exerciseType: ExerciseType.strength,
          description: 'Machine isolation for the quadriceps.',
          instructions:
            'Sit in a leg extension machine with pad on shins. Extend legs to full lockout, squeezing quads at the top, then lower under control.',
          muscles: [{ name: 'quadriceps', primary: true }],
          equipment: ['leg_extension_machine'],
        },
        {
          name: 'Leg Curl',
          exerciseType: ExerciseType.strength,
          description: 'Machine isolation for the hamstrings.',
          instructions:
            'Lie face-down on a leg curl machine with pad behind your heels. Curl heels toward your glutes, hold briefly, then lower fully.',
          muscles: [{ name: 'hamstrings', primary: true }],
          equipment: ['leg_curl_machine'],
        },
        {
          name: 'Hip Thrust',
          exerciseType: ExerciseType.strength,
          description: 'Glute-dominant hip extension with a barbell over the hips.',
          instructions:
            'Sit with upper back against a bench, barbell over hips. Plant feet flat. Drive through heels, extending hips to a straight line from knees to shoulders. Squeeze glutes at top.',
          muscles: [
            { name: 'glutes', primary: true },
            { name: 'hamstrings', primary: false },
            { name: 'core', primary: false },
          ],
          equipment: ['barbell', 'bench'],
        },
        {
          name: 'Standing Calf Raise',
          exerciseType: ExerciseType.strength,
          description: 'Isolation exercise for the gastrocnemius (upper calf).',
          instructions:
            'Stand on the edge of a step or calf raise machine. Rise onto the balls of your feet as high as possible, hold briefly, then lower fully for a stretch.',
          muscles: [{ name: 'calves', primary: true }],
          equipment: ['bodyweight'],
        },
        {
          name: 'Seated Calf Raise',
          exerciseType: ExerciseType.strength,
          description: 'Targets the soleus (lower calf) due to bent-knee position.',
          instructions:
            'Sit on a calf raise machine with knees at 90° and pads on thighs. Rise onto the balls of your feet, hold at the top, then lower for a full stretch.',
          muscles: [{ name: 'calves', primary: true }],
          equipment: ['calf_raise_machine'],
        },
        {
          name: 'Hack Squat',
          exerciseType: ExerciseType.strength,
          description: 'Machine squat variant allowing deep knee bend with quad emphasis.',
          instructions:
            'Load the hack squat machine, place feet shoulder-width on the platform. Unhook safeties, lower by bending knees until thighs are below parallel, then drive back up.',
          muscles: [
            { name: 'quadriceps', primary: true },
            { name: 'glutes', primary: false },
          ],
          equipment: ['hack_squat_machine'],
        },

        // ── Core (Strength) ───────────────────────────────────
        {
          name: 'Plank',
          exerciseType: ExerciseType.strength,
          description: 'Isometric core stability exercise performed in a forearm plank position.',
          instructions:
            'Support yourself on forearms and toes, body forming a straight line from head to heels. Brace abs and glutes. Hold without letting hips drop or pike.',
          muscles: [
            { name: 'core', primary: true },
            { name: 'abs', primary: true },
            { name: 'lower_back', primary: false },
          ],
          equipment: ['bodyweight'],
        },
        {
          name: 'Crunch',
          exerciseType: ExerciseType.strength,
          description: 'Basic ab isolation movement for the rectus abdominis.',
          instructions:
            'Lie on your back with knees bent, hands behind head. Lift only your shoulder blades off the floor by contracting the abs, then lower slowly. Do not pull on your neck.',
          muscles: [{ name: 'abs', primary: true }],
          equipment: ['bodyweight', 'yoga_mat'],
        },
        {
          name: 'Hanging Leg Raise',
          exerciseType: ExerciseType.strength,
          description: 'Challenging lower ab and hip flexor exercise from a hanging position.',
          instructions:
            'Hang from a pull-up bar with straight arms. Keeping legs straight or knees bent, raise legs until they reach at least 90°, then lower under control.',
          muscles: [
            { name: 'abs', primary: true },
            { name: 'hip_flexors', primary: true },
            { name: 'core', primary: false },
          ],
          equipment: ['pull_up_bar', 'bodyweight'],
        },
        {
          name: 'Ab Wheel Rollout',
          exerciseType: ExerciseType.strength,
          description: 'Advanced anti-extension core exercise using an ab wheel.',
          instructions:
            'Kneel on a mat holding an ab wheel in both hands. Roll the wheel forward until your torso is nearly parallel to the floor, then contract abs to roll back.',
          muscles: [
            { name: 'abs', primary: true },
            { name: 'core', primary: true },
            { name: 'lower_back', primary: false },
          ],
          equipment: ['ab_wheel', 'yoga_mat'],
        },
        {
          name: 'Russian Twist',
          exerciseType: ExerciseType.strength,
          description: 'Rotational exercise targeting the obliques.',
          instructions:
            'Sit with knees bent and torso leaned back 45°. Hold hands together or a weight. Rotate torso from side to side, touching the floor (or weight) beside each hip.',
          muscles: [
            { name: 'abs', primary: true },
            { name: 'core', primary: true },
          ],
          equipment: ['bodyweight', 'yoga_mat'],
        },
        {
          name: 'Sit-Up',
          exerciseType: ExerciseType.strength,
          description: 'Full range of motion ab curl through sitting position.',
          instructions:
            'Lie on your back with knees bent and feet anchored. Arms crossed on chest or hands beside ears. Curl all the way up to a seated position, then lower under control.',
          muscles: [
            { name: 'abs', primary: true },
            { name: 'hip_flexors', primary: false },
          ],
          equipment: ['bodyweight', 'yoga_mat'],
        },
        {
          name: 'Leg Raise',
          exerciseType: ExerciseType.strength,
          description: 'Lying leg raise for the lower abs.',
          instructions:
            'Lie flat on your back, legs together. Keeping legs straight, raise them to 90°, then lower them slowly without letting them touch the floor. Keep lower back pressed down.',
          muscles: [
            { name: 'abs', primary: true },
            { name: 'hip_flexors', primary: false },
          ],
          equipment: ['bodyweight', 'yoga_mat'],
        },
        {
          name: 'Cable Woodchopper',
          exerciseType: ExerciseType.strength,
          description: 'Rotational cable exercise for the obliques and transverse abs.',
          instructions:
            'Set a cable pulley high on one side. Stand perpendicular to the machine. Pull the handle diagonally down and across your body in a chopping motion, rotating hips and torso.',
          muscles: [
            { name: 'core', primary: true },
            { name: 'abs', primary: true },
            { name: 'shoulders', primary: false },
          ],
          equipment: ['cable_machine'],
        },

        // ── Full Body (Strength) ──────────────────────────────
        {
          name: 'Barbell Clean',
          exerciseType: ExerciseType.strength,
          description: 'Olympic lift pulling a barbell from the floor to the front rack position.',
          instructions:
            'Start with barbell over mid-foot, grip just outside hips. Explosively extend hips and shrug, then pull yourself under the bar, rotating elbows forward into the front rack. Stand tall.',
          muscles: [
            { name: 'glutes', primary: true },
            { name: 'hamstrings', primary: true },
            { name: 'traps', primary: true },
            { name: 'quadriceps', primary: false },
            { name: 'core', primary: false },
          ],
          equipment: ['barbell'],
        },
        {
          name: 'Thruster',
          exerciseType: ExerciseType.strength,
          description: 'Combination front squat and overhead press in one fluid movement.',
          instructions:
            'Hold a barbell or dumbbells in the front rack. Squat to depth, then drive up explosively using the momentum to press the weight overhead to full lockout.',
          muscles: [
            { name: 'quadriceps', primary: true },
            { name: 'glutes', primary: true },
            { name: 'shoulders', primary: true },
            { name: 'triceps', primary: false },
            { name: 'core', primary: false },
          ],
          equipment: ['barbell'],
        },
        {
          name: 'Kettlebell Swing',
          exerciseType: ExerciseType.strength,
          description: 'Ballistic hip-hinge movement using a kettlebell to develop power and conditioning.',
          instructions:
            'Stand with feet shoulder-width, kettlebell between feet. Hinge at hips and swing the bell back between legs, then snap hips forward explosively to swing it to chest height.',
          muscles: [
            { name: 'glutes', primary: true },
            { name: 'hamstrings', primary: true },
            { name: 'core', primary: true },
            { name: 'lower_back', primary: false },
          ],
          equipment: ['kettlebell'],
        },
        {
          name: "Farmer's Carry",
          exerciseType: ExerciseType.strength,
          description: 'Loaded carry for grip, traps, and full-body stability.',
          instructions:
            'Pick up heavy dumbbells or kettlebells in each hand. Stand tall and walk for a set distance or time, keeping core braced and shoulders packed.',
          muscles: [
            { name: 'forearms', primary: true },
            { name: 'traps', primary: true },
            { name: 'core', primary: true },
          ],
          equipment: ['dumbbell'],
        },
        {
          name: 'Box Jump',
          exerciseType: ExerciseType.strength,
          description: 'Explosive plyometric jump onto a box for lower body power.',
          instructions:
            'Stand in front of a plyo box. Dip into a quarter squat, swing arms, and jump onto the box, landing softly with both feet. Step or jump back down.',
          muscles: [
            { name: 'quadriceps', primary: true },
            { name: 'glutes', primary: true },
            { name: 'calves', primary: false },
          ],
          equipment: ['box', 'bodyweight'],
        },
        {
          name: 'Dumbbell Snatch',
          exerciseType: ExerciseType.strength,
          description: 'Single-arm explosive pull from floor to overhead in one movement.',
          instructions:
            "Stand over a dumbbell with feet hip-width. Pull the dumbbell from the floor explosively, extending hips, then punch it overhead in one fluid motion. Lock out arm at the top.",
          muscles: [
            { name: 'glutes', primary: true },
            { name: 'hamstrings', primary: true },
            { name: 'shoulders', primary: true },
            { name: 'traps', primary: true },
            { name: 'core', primary: false },
          ],
          equipment: ['dumbbell'],
        },
        {
          name: 'Battle Ropes',
          exerciseType: ExerciseType.strength,
          description: 'High-intensity conditioning using heavy ropes for arms and conditioning.',
          instructions:
            'Stand in a partial squat holding one end of each rope. Alternate or simultaneously slam the ropes up and down in waves with maximum effort for the prescribed duration.',
          muscles: [
            { name: 'shoulders', primary: true },
            { name: 'core', primary: true },
            { name: 'back', primary: false },
          ],
          equipment: ['battle_ropes'],
        },
        {
          name: 'Sled Push',
          exerciseType: ExerciseType.strength,
          description: 'Loaded sled push for lower body power and conditioning.',
          instructions:
            "Load a sled and grip the upright handles at arm's length. Drive forward by pushing through the floor with alternating steps, keeping torso at about 45°.",
          muscles: [
            { name: 'quadriceps', primary: true },
            { name: 'glutes', primary: true },
            { name: 'calves', primary: false },
            { name: 'core', primary: false },
          ],
          equipment: ['sled'],
        },

        // ── Cardio ────────────────────────────────────────────
        {
          name: 'Running',
          exerciseType: ExerciseType.cardio,
          description: 'Steady-state outdoor or treadmill running for cardiovascular health.',
          instructions:
            'Run at a conversational to moderate pace. Maintain an upright posture, land mid-foot, and breathe rhythmically. Adjust speed and duration based on fitness level.',
          muscles: [
            { name: 'quadriceps', primary: true },
            { name: 'hamstrings', primary: false },
            { name: 'calves', primary: false },
            { name: 'glutes', primary: false },
          ],
          equipment: ['treadmill'],
        },
        {
          name: 'Walking',
          exerciseType: ExerciseType.cardio,
          description: 'Low-impact aerobic activity suitable for all fitness levels.',
          instructions:
            'Walk at a brisk pace with arms swinging naturally. Keep posture upright and core lightly engaged. Aim for 30+ minutes for health benefits.',
          muscles: [
            { name: 'glutes', primary: true },
            { name: 'quadriceps', primary: false },
            { name: 'calves', primary: false },
          ],
          equipment: ['bodyweight'],
        },
        {
          name: 'Outdoor Cycling',
          exerciseType: ExerciseType.cardio,
          description: 'Road or trail cycling for low-impact cardiovascular endurance.',
          instructions:
            'Ride at a moderate to high intensity. Keep cadence between 80–100 RPM. Adjust gears to maintain effort over varied terrain.',
          muscles: [
            { name: 'quadriceps', primary: true },
            { name: 'hamstrings', primary: false },
            { name: 'calves', primary: false },
            { name: 'glutes', primary: false },
          ],
          equipment: ['bicycle'],
        },
        {
          name: 'Stationary Bike',
          exerciseType: ExerciseType.cardio,
          description: 'Indoor cycling on a stationary bike for low-impact cardio.',
          instructions:
            'Set seat height so knee has a slight bend at the bottom of the pedal stroke. Pedal at a consistent cadence, adjusting resistance to keep heart rate in target zone.',
          muscles: [
            { name: 'quadriceps', primary: true },
            { name: 'hamstrings', primary: false },
            { name: 'calves', primary: false },
          ],
          equipment: ['stationary_bike'],
        },
        {
          name: 'Rowing Machine',
          exerciseType: ExerciseType.cardio,
          description: 'Full-body cardio on a rowing ergometer working legs, back, and arms.',
          instructions:
            'Drive through legs first, then lean back slightly, and pull the handle to your lower sternum. Return by extending arms, leaning forward, then bending knees.',
          muscles: [
            { name: 'back', primary: true },
            { name: 'lats', primary: true },
            { name: 'quadriceps', primary: true },
            { name: 'hamstrings', primary: false },
            { name: 'biceps', primary: false },
          ],
          equipment: ['rowing_machine'],
        },
        {
          name: 'Jump Rope',
          exerciseType: ExerciseType.cardio,
          description: 'High-intensity cardio using a jump rope to improve coordination.',
          instructions:
            'Hold rope handles with palms forward at hip height. Use wrist rotation to swing the rope. Jump with both feet, landing softly on the balls of your feet.',
          muscles: [
            { name: 'calves', primary: true },
            { name: 'core', primary: false },
            { name: 'shoulders', primary: false },
          ],
          equipment: ['jump_rope'],
        },
        {
          name: 'Elliptical',
          exerciseType: ExerciseType.cardio,
          description: 'Low-impact full-body cardio on an elliptical trainer.',
          instructions:
            'Step onto the pedals and grip handles. Move legs in an elliptical stride while pushing and pulling the handles. Maintain upright posture throughout.',
          muscles: [
            { name: 'quadriceps', primary: true },
            { name: 'hamstrings', primary: false },
            { name: 'glutes', primary: false },
            { name: 'back', primary: false },
          ],
          equipment: ['elliptical'],
        },
        {
          name: 'Swimming',
          exerciseType: ExerciseType.cardio,
          description: 'Full-body zero-impact cardio in a pool.',
          instructions:
            'Choose a stroke (freestyle, breaststroke, backstroke). Maintain a horizontal body position, breathe rhythmically, and complete laps at your target effort level.',
          muscles: [
            { name: 'back', primary: true },
            { name: 'lats', primary: true },
            { name: 'shoulders', primary: true },
            { name: 'core', primary: false },
          ],
          equipment: ['pool'],
        },
        {
          name: 'Burpees',
          exerciseType: ExerciseType.cardio,
          description: 'High-intensity full-body exercise combining a squat, plank, push-up, and jump.',
          instructions:
            'From standing, drop hands to the floor, jump feet back to plank, perform a push-up, jump feet forward to hands, then explode upward into a jump with arms overhead.',
          muscles: [
            { name: 'quadriceps', primary: true },
            { name: 'core', primary: true },
            { name: 'chest', primary: false },
            { name: 'shoulders', primary: false },
          ],
          equipment: ['bodyweight'],
        },
        {
          name: 'Mountain Climbers',
          exerciseType: ExerciseType.cardio,
          description: 'Dynamic core and cardio drill performed from a plank position.',
          instructions:
            'Start in a high plank. Drive one knee toward your chest, then quickly switch legs in a running motion. Keep hips level and core braced throughout.',
          muscles: [
            { name: 'core', primary: true },
            { name: 'hip_flexors', primary: true },
            { name: 'shoulders', primary: false },
          ],
          equipment: ['bodyweight'],
        },
        {
          name: 'Jumping Jacks',
          exerciseType: ExerciseType.cardio,
          description: 'Classic full-body warm-up and low-intensity cardio movement.',
          instructions:
            'Stand with feet together and arms at sides. Jump feet out wide as you raise arms overhead, then jump back to start. Maintain a steady rhythm.',
          muscles: [
            { name: 'calves', primary: true },
            { name: 'adductors', primary: false },
            { name: 'shoulders', primary: false },
          ],
          equipment: ['bodyweight'],
        },
        {
          name: 'High Knees',
          exerciseType: ExerciseType.cardio,
          description: 'Running in place with exaggerated knee drive for cardio and hip flexor work.',
          instructions:
            'Run in place, driving alternating knees up toward your chest as quickly as possible. Pump opposite arm with each knee drive. Land softly on the balls of your feet.',
          muscles: [
            { name: 'hip_flexors', primary: true },
            { name: 'quadriceps', primary: false },
            { name: 'calves', primary: false },
          ],
          equipment: ['bodyweight'],
        },
        {
          name: 'Sprint',
          exerciseType: ExerciseType.cardio,
          description: 'Short-distance maximal effort run for speed and power development.',
          instructions:
            'From a standing or crouching start, accelerate to maximum speed over 20–100m. Drive arms powerfully, lean slightly forward, and land on the balls of your feet.',
          muscles: [
            { name: 'quadriceps', primary: true },
            { name: 'hamstrings', primary: true },
            { name: 'glutes', primary: true },
            { name: 'calves', primary: false },
          ],
          equipment: ['bodyweight'],
        },
        {
          name: 'Stair Climber',
          exerciseType: ExerciseType.cardio,
          description: 'Sustained stair climbing on a machine for glute and cardio conditioning.',
          instructions:
            'Step onto the stair climber and set your desired speed. Alternate feet on the steps, standing tall with light grip on handrails for balance only.',
          muscles: [
            { name: 'glutes', primary: true },
            { name: 'quadriceps', primary: true },
            { name: 'calves', primary: false },
          ],
          equipment: ['stair_climber'],
        },
        {
          name: 'HIIT Circuit',
          exerciseType: ExerciseType.cardio,
          description: 'Alternating high-intensity work intervals with short rest periods.',
          instructions:
            'Choose 4–6 exercises. Perform each for 20–40 seconds at maximum effort followed by 10–20 seconds rest. Complete 3–5 rounds.',
          muscles: [
            { name: 'core', primary: true },
            { name: 'quadriceps', primary: true },
            { name: 'glutes', primary: false },
          ],
          equipment: ['bodyweight'],
        },

        // ── Stretching / Mobility ─────────────────────────────
        {
          name: 'Standing Hamstring Stretch',
          exerciseType: ExerciseType.stretching,
          description: 'Gentle stretch for the hamstrings performed while standing.',
          instructions:
            'Stand with one foot extended in front with heel on the floor and toe pointing up. Hinge forward at the hips with a flat back until you feel a stretch behind the thigh. Hold 30 s per side.',
          muscles: [{ name: 'hamstrings', primary: true }],
          equipment: ['bodyweight'],
        },
        {
          name: 'Kneeling Hip Flexor Stretch',
          exerciseType: ExerciseType.stretching,
          description: 'Targets the hip flexors and iliopsoas, often tight from prolonged sitting.',
          instructions:
            'Drop into a half-kneeling position (one knee on floor). Shift hips forward until you feel a stretch at the front of the rear hip. Keep torso upright and core engaged. Hold 30 s per side.',
          muscles: [
            { name: 'hip_flexors', primary: true },
            { name: 'quadriceps', primary: false },
          ],
          equipment: ['bodyweight', 'yoga_mat'],
        },
        {
          name: 'Doorway Chest Stretch',
          exerciseType: ExerciseType.stretching,
          description: 'Static stretch for the pectorals using a doorframe.',
          instructions:
            'Stand in a doorway. Place forearms on the door frame with elbows at shoulder height. Step forward until you feel a stretch across the chest. Hold 30 s.',
          muscles: [
            { name: 'chest', primary: true },
            { name: 'shoulders', primary: false },
          ],
          equipment: ['bodyweight'],
        },
        {
          name: 'Cross-Body Shoulder Stretch',
          exerciseType: ExerciseType.stretching,
          description: 'Horizontal adduction stretch targeting the posterior deltoid.',
          instructions:
            'Bring one arm across your chest at shoulder height. Use the other hand to gently press it in. Hold 30 s per side.',
          muscles: [{ name: 'shoulders', primary: true }],
          equipment: ['bodyweight'],
        },
        {
          name: 'Standing Quad Stretch',
          exerciseType: ExerciseType.stretching,
          description: 'Standing stretch for the quadriceps.',
          instructions:
            'Stand on one leg. Bend the other knee and hold your ankle behind you. Keep knees together and stand tall. Hold 30 s per side. Use a wall for balance if needed.',
          muscles: [{ name: 'quadriceps', primary: true }],
          equipment: ['bodyweight'],
        },
        {
          name: 'Pigeon Pose',
          exerciseType: ExerciseType.stretching,
          description: 'Deep hip-opener targeting the glutes and hip external rotators.',
          instructions:
            'From a plank, bring one knee forward behind your wrist. Extend the other leg straight behind. Lower your torso over the bent leg for a deeper stretch. Hold 1 min per side.',
          muscles: [
            { name: 'glutes', primary: true },
            { name: 'hip_flexors', primary: true },
          ],
          equipment: ['bodyweight', 'yoga_mat'],
        },
        {
          name: "Child's Pose",
          exerciseType: ExerciseType.stretching,
          description: 'Resting yoga pose that gently stretches the lower back, hips, and shoulders.',
          instructions:
            'Kneel on a mat, sit back on your heels, and walk hands forward as you lower your forehead to the mat. Reach arms overhead or rest beside your body. Hold 1–2 min.',
          muscles: [
            { name: 'lower_back', primary: true },
            { name: 'glutes', primary: false },
            { name: 'shoulders', primary: false },
          ],
          equipment: ['bodyweight', 'yoga_mat'],
        },
        {
          name: 'Cobra Stretch',
          exerciseType: ExerciseType.stretching,
          description: 'Spinal extension stretch for the abdomen and lower back.',
          instructions:
            'Lie face-down with hands beside shoulders. Press through hands to lift your chest, keeping hips on the floor. Hold 20–30 s and feel the stretch in abs and lower back.',
          muscles: [
            { name: 'abs', primary: true },
            { name: 'lower_back', primary: false },
          ],
          equipment: ['bodyweight', 'yoga_mat'],
        },
        {
          name: 'Cat-Cow Stretch',
          exerciseType: ExerciseType.stretching,
          description: 'Dynamic spinal mobility drill alternating between flexion and extension.',
          instructions:
            'On hands and knees, alternate between rounding (cat: chin to chest, tailbone tucked) and arching (cow: chest up, tailbone raised). Move slowly with your breath for 10 reps.',
          muscles: [
            { name: 'lower_back', primary: true },
            { name: 'core', primary: false },
          ],
          equipment: ['bodyweight', 'yoga_mat'],
        },
        {
          name: 'Seated Butterfly Stretch',
          exerciseType: ExerciseType.stretching,
          description: 'Seated groin and inner thigh stretch.',
          instructions:
            'Sit on the floor with soles of feet pressed together. Hold feet and gently press knees toward the floor with your elbows. Maintain an upright spine. Hold 30 s.',
          muscles: [
            { name: 'adductors', primary: true },
            { name: 'hip_flexors', primary: false },
          ],
          equipment: ['bodyweight', 'yoga_mat'],
        },
        {
          name: 'IT Band Stretch',
          exerciseType: ExerciseType.stretching,
          description: 'Lateral leg cross-over stretch for the iliotibial band.',
          instructions:
            'Stand and cross one foot behind the other. Lean the opposite hip out to the side until you feel tension along the outer thigh of the rear leg. Hold 30 s per side.',
          muscles: [
            { name: 'glutes', primary: true },
            { name: 'adductors', primary: false },
          ],
          equipment: ['bodyweight'],
        },
        {
          name: 'Wall Calf Stretch',
          exerciseType: ExerciseType.stretching,
          description: 'Static gastrocnemius stretch using a wall for support.',
          instructions:
            'Face a wall with hands on the surface. Step one foot back with heel flat on the floor. Lean forward until you feel a calf stretch. Hold 30 s, then switch sides.',
          muscles: [{ name: 'calves', primary: true }],
          equipment: ['bodyweight'],
        },
        {
          name: 'Neck Side Stretch',
          exerciseType: ExerciseType.stretching,
          description: 'Gentle lateral cervical stretch to release neck and upper trap tension.',
          instructions:
            'Sit or stand tall. Tilt your right ear toward your right shoulder. Optionally place right hand on the side of your head for light added pressure. Hold 20–30 s per side.',
          muscles: [{ name: 'traps', primary: true }],
          equipment: ['bodyweight'],
        },
        {
          name: 'Thoracic Rotation Stretch',
          exerciseType: ExerciseType.stretching,
          description: 'Mobility drill for mid-back rotation, important for posture and overhead work.',
          instructions:
            'Sit cross-legged or on a chair. Place one hand behind your head and rotate that elbow toward the ceiling, opening the chest. Return and repeat. Do 10 reps per side.',
          muscles: [
            { name: 'back', primary: true },
            { name: 'lower_back', primary: false },
          ],
          equipment: ['bodyweight', 'yoga_mat'],
        },
        {
          name: 'Foam Roll Thoracic Spine',
          exerciseType: ExerciseType.stretching,
          description: 'Foam rolling mobilization for the upper back and thoracic spine.',
          instructions:
            'Sit in front of a foam roller, then lean back onto it at mid-back. Support your head with hands, and gently extend over the roller segment by segment. Hold on tight spots 20–30 s.',
          muscles: [
            { name: 'back', primary: true },
            { name: 'lower_back', primary: false },
          ],
          equipment: ['foam_roller'],
        },
        {
          name: 'Foam Roll IT Band',
          exerciseType: ExerciseType.stretching,
          description: 'Self-myofascial release for the outer thigh and IT band.',
          instructions:
            'Lie on your side with the foam roller under your outer thigh. Support with hands and top foot. Slowly roll from hip to just above the knee. Pause on tender spots.',
          muscles: [
            { name: 'glutes', primary: true },
            { name: 'adductors', primary: false },
          ],
          equipment: ['foam_roller'],
        },
        {
          name: 'Foam Roll Quadriceps',
          exerciseType: ExerciseType.stretching,
          description: 'Self-myofascial release for tight quads before and after workouts.',
          instructions:
            'Lie face-down with the foam roller under your thighs. Support on forearms and slowly roll from hips down to just above the knee. Pause on tight areas.',
          muscles: [{ name: 'quadriceps', primary: true }],
          equipment: ['foam_roller'],
        },
        {
          name: 'Wrist Flexor Stretch',
          exerciseType: ExerciseType.stretching,
          description: 'Stretch for the wrist flexors and forearm, important for pressing work.',
          instructions:
            'Extend one arm in front with palm facing up. Use the other hand to gently press fingers down toward the floor until you feel a stretch in the forearm. Hold 30 s per side.',
          muscles: [{ name: 'forearms', primary: true }],
          equipment: ['bodyweight'],
        },
        {
          name: 'Overhead Triceps Stretch',
          exerciseType: ExerciseType.stretching,
          description: 'Static stretch for the triceps and the long head in particular.',
          instructions:
            'Raise one arm overhead, bend the elbow so your hand reaches down your upper back. Use the other hand to gently push the elbow further down. Hold 30 s per side.',
          muscles: [{ name: 'triceps', primary: true }],
          equipment: ['bodyweight'],
        },
        {
          name: 'Hip Circle',
          exerciseType: ExerciseType.stretching,
          description: 'Dynamic warm-up rotation to lubricate the hip joint.',
          instructions:
            'Stand with feet shoulder-width. Place hands on hips and rotate them in large circles — 10 clockwise, then 10 counter-clockwise. Keep movement smooth and controlled.',
          muscles: [
            { name: 'hip_flexors', primary: true },
            { name: 'glutes', primary: false },
          ],
          equipment: ['bodyweight'],
        },
        {
          name: "World's Greatest Stretch",
          exerciseType: ExerciseType.stretching,
          description: 'Multi-joint dynamic stretch combining a lunge, rotation, and hip opener.',
          instructions:
            'Step into a deep lunge. Place the same-side hand on the floor beside your foot. Rotate and reach the opposite arm toward the ceiling. Sink hips low. Do 5 reps per side.',
          muscles: [
            { name: 'hip_flexors', primary: true },
            { name: 'glutes', primary: true },
            { name: 'back', primary: false },
            { name: 'shoulders', primary: false },
          ],
          equipment: ['bodyweight', 'yoga_mat'],
        },
        {
          name: 'Seated Forward Fold',
          exerciseType: ExerciseType.stretching,
          description: 'Seated hamstring and lower back stretch with a forward fold.',
          instructions:
            'Sit with legs extended straight. Reach both hands toward your feet, hinging at the hips. Keep spine long rather than rounding. Hold 30–60 s.',
          muscles: [
            { name: 'hamstrings', primary: true },
            { name: 'lower_back', primary: false },
            { name: 'calves', primary: false },
          ],
          equipment: ['bodyweight', 'yoga_mat'],
        },
        {
          name: 'Figure-Four Glute Stretch',
          exerciseType: ExerciseType.stretching,
          description: 'Supine piriformis and glute stretch.',
          instructions:
            'Lie on your back, cross one ankle over the opposite knee. Pull the uncrossed leg toward your chest until you feel a deep stretch in the crossed-leg glute. Hold 30 s per side.',
          muscles: [{ name: 'glutes', primary: true }],
          equipment: ['bodyweight', 'yoga_mat'],
        },
      ];

      // Insert exercises with muscle group and equipment links
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
                muscleGroupId: mg[m.name],
                isPrimary: m.primary,
              })),
            },
            equipment: {
              create: ex.equipment.map((e) => ({
                equipmentId: eq[e],
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
                      exerciseId: exercises['Barbell Curl'],
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
                      exerciseId: exercises['Romanian Deadlift'],
                      sortOrder: 1,
                      targetSets: 3,
                      targetReps: '10-12',
                    },
                    {
                      exerciseId: exercises['Plank'],
                      sortOrder: 2,
                      targetSets: 3,
                      targetDurationSec: 60,
                    },
                    {
                      exerciseId: exercises['Running'],
                      sortOrder: 3,
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

      const strengthCount = exerciseData.filter((e) => e.exerciseType === ExerciseType.strength).length;
      const cardioCount = exerciseData.filter((e) => e.exerciseType === ExerciseType.cardio).length;
      const stretchingCount = exerciseData.filter((e) => e.exerciseType === ExerciseType.stretching).length;

      console.log('Seed completed successfully');
      console.log(
        `Created: 2 users, ${muscleGroupData.length} muscle groups, ${equipmentData.length} equipment types, ${exerciseData.length} exercises (${strengthCount} strength, ${cardioCount} cardio, ${stretchingCount} stretching), 1 workout plan`,
      );
    },
    { timeout: 60000 },
  );
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
