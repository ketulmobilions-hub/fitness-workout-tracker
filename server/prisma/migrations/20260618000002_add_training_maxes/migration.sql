CREATE TABLE "training_maxes" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "exercise_id" UUID NOT NULL,
    "training_max_kg" DOUBLE PRECISION NOT NULL,
    "percentage_of_1rm" DOUBLE PRECISION NOT NULL DEFAULT 90,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "training_maxes_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "training_maxes_user_id_exercise_id_key" ON "training_maxes"("user_id", "exercise_id");
CREATE INDEX "training_maxes_user_id_idx" ON "training_maxes"("user_id");

ALTER TABLE "training_maxes" ADD CONSTRAINT "training_maxes_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "training_maxes" ADD CONSTRAINT "training_maxes_exercise_id_fkey"
    FOREIGN KEY ("exercise_id") REFERENCES "exercises"("id") ON DELETE CASCADE ON UPDATE CASCADE;
