import { Router } from 'express';
import * as reference from '../controllers/reference.controller.js';

const router = Router();

// No auth — weight classes are public reference data used by the onboarding flow
// before a user has logged in.
router.get('/weight-classes', reference.getWeightClasses);

export default router;
