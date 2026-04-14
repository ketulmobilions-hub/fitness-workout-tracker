-- CreateIndex: unique constraint on exercises.name
CREATE UNIQUE INDEX "exercises_name_key" ON "exercises"("name");

-- CreateIndex: reverse FK index on exercise_muscle_groups.muscle_group_id
CREATE INDEX "exercise_muscle_groups_muscle_group_id_idx" ON "exercise_muscle_groups"("muscle_group_id");

-- CreateIndex: reverse FK index on exercise_equipment.equipment_id
CREATE INDEX "exercise_equipment_equipment_id_idx" ON "exercise_equipment"("equipment_id");
