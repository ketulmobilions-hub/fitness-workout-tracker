CREATE TYPE "CompetitionStatus" AS ENUM ('upcoming', 'completed');
CREATE TYPE "LiftType" AS ENUM ('squat', 'bench', 'deadlift');
CREATE TYPE "AttemptResult" AS ENUM ('good_lift', 'no_lift', 'not_taken');

CREATE TABLE "competitions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "federation" TEXT,
    "date" DATE NOT NULL,
    "location" TEXT,
    "weight_class_kg" DOUBLE PRECISION,
    "bodyweight_kg" DOUBLE PRECISION,
    "division" TEXT,
    "status" "CompetitionStatus" NOT NULL DEFAULT 'upcoming',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "competitions_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "competition_attempts" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "competition_id" UUID NOT NULL,
    "lift_type" "LiftType" NOT NULL,
    "attempt_number" INTEGER NOT NULL,
    "weight_kg" DOUBLE PRECISION NOT NULL,
    "result" "AttemptResult" NOT NULL DEFAULT 'not_taken',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "competition_attempts_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "competitions_user_id_idx" ON "competitions"("user_id");
CREATE INDEX "competitions_user_id_date_idx" ON "competitions"("user_id", "date");
CREATE INDEX "competition_attempts_competition_id_idx" ON "competition_attempts"("competition_id");

-- Each (lift_type, attempt_number) pair must be unique per competition
CREATE UNIQUE INDEX "competition_attempts_competition_lift_attempt_key"
    ON "competition_attempts"("competition_id", "lift_type", "attempt_number");

ALTER TABLE "competitions"
    ADD CONSTRAINT "competitions_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "competition_attempts"
    ADD CONSTRAINT "competition_attempts_competition_id_fkey"
    FOREIGN KEY ("competition_id") REFERENCES "competitions"("id") ON DELETE CASCADE ON UPDATE CASCADE;
