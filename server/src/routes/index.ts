import { Router } from 'express';
import healthRoutes from './health.routes.js';
import authRoutes from './auth.routes.js';
import exerciseRoutes from './exercise.routes.js';
import muscleGroupRoutes from './muscle-group.routes.js';
import planRoutes from './plan.routes.js';
import sessionRoutes from './session.routes.js';
import syncRoutes from './sync.routes.js';
import progressRoutes from './progress.routes.js';

const router = Router();

router.use('/health', healthRoutes);
router.use('/auth', authRoutes);
router.use('/exercises', exerciseRoutes);
router.use('/muscle-groups', muscleGroupRoutes);
router.use('/plans', planRoutes);
router.use('/sessions', sessionRoutes);
router.use('/sync', syncRoutes);
router.use('/progress', progressRoutes);

export default router;
