-- AlterTable
ALTER TABLE "workout_plans" ADD COLUMN     "numWeeks" INTEGER NOT NULL DEFAULT 1,
ALTER COLUMN "startDate" SET DATA TYPE DATE;

-- AlterTable
ALTER TABLE "workout_routines" ADD COLUMN     "isDraft" BOOLEAN NOT NULL DEFAULT false;
