-- AlterTable: add target_weight_pct_1rm to plan_day_exercises for % of 1RM auto-suggest
ALTER TABLE "plan_day_exercises" ADD COLUMN "target_weight_pct_1rm" DOUBLE PRECISION;
