-- AlterTable
ALTER TABLE "diet_plans" ADD COLUMN     "numWeeks" INTEGER NOT NULL DEFAULT 1,
ADD COLUMN     "weekTargets" JSONB;

-- AlterTable
ALTER TABLE "meals" ADD COLUMN     "isDraft" BOOLEAN NOT NULL DEFAULT false;
