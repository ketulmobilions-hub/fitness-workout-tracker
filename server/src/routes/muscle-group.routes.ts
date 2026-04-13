import { Router } from 'express';
import * as muscleGroup from '../controllers/muscle-group.controller.js';

const router = Router();

router.get('/', muscleGroup.getMuscleGroups);

export default router;
