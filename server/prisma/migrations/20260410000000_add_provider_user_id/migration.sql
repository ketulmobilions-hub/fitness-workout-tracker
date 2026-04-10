-- AlterTable: add provider_user_id to users for OAuth account linking
-- This stores the provider-issued subject identifier (Google sub / Apple sub)
-- so returning social-login users can be looked up by their stable provider ID
-- without relying on email (Apple only sends email on first authorization).
ALTER TABLE "users" ADD COLUMN "provider_user_id" TEXT;

-- CreateIndex: enforce one account per social identity
CREATE UNIQUE INDEX "users_provider_user_id_key" ON "users"("provider_user_id");
