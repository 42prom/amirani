-- Add meal log state to both master_meals (template) and meals (hydrated instances)
ALTER TABLE "master_meals" ADD COLUMN IF NOT EXISTS "isLogged" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "master_meals" ADD COLUMN IF NOT EXISTS "loggedAt" TIMESTAMP(3);

ALTER TABLE "meals" ADD COLUMN IF NOT EXISTS "isLogged" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "meals" ADD COLUMN IF NOT EXISTS "loggedAt" TIMESTAMP(3);
