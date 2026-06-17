-- AlterTable
ALTER TABLE "users"
  ADD COLUMN "federation"      VARCHAR,
  ADD COLUMN "division"        VARCHAR,
  ADD COLUMN "weight_class_kg" DOUBLE PRECISION,
  ADD COLUMN "bodyweight_kg"   DOUBLE PRECISION,
  ADD COLUMN "gender"          VARCHAR;

-- Enforce allowed gender values at the DB layer.
ALTER TABLE "users"
  ADD CONSTRAINT "users_gender_check" CHECK ("gender" IN ('M', 'F', 'Mx'));
