-- CreateTable
CREATE TABLE "equipment" (
    "id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "display_name" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "equipment_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "exercise_equipment" (
    "exercise_id" UUID NOT NULL,
    "equipment_id" UUID NOT NULL,

    CONSTRAINT "exercise_equipment_pkey" PRIMARY KEY ("exercise_id","equipment_id")
);

-- CreateIndex
CREATE UNIQUE INDEX "equipment_name_key" ON "equipment"("name");

-- AddForeignKey
ALTER TABLE "exercise_equipment" ADD CONSTRAINT "exercise_equipment_exercise_id_fkey" FOREIGN KEY ("exercise_id") REFERENCES "exercises"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "exercise_equipment" ADD CONSTRAINT "exercise_equipment_equipment_id_fkey" FOREIGN KEY ("equipment_id") REFERENCES "equipment"("id") ON DELETE CASCADE ON UPDATE CASCADE;
