-- DropIndex
DROP INDEX "workout_plans_user_id_idx";

-- CreateIndex
CREATE INDEX "workout_plans_user_id_deleted_at_idx" ON "workout_plans"("user_id", "deleted_at");
