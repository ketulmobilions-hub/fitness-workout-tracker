-- CreateIndex
CREATE INDEX "personal_records_user_id_exercise_id_record_type_idx" ON "personal_records"("user_id", "exercise_id", "record_type");
