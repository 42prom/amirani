-- AlterTable: Remove redundant isDeleted flag, use deletedAt for soft-delete pattern
ALTER TABLE "daily_progress" DROP COLUMN "isDeleted",
ADD COLUMN "deletedAt" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "diet_plans" DROP COLUMN "isDeleted";

-- AlterTable
ALTER TABLE "workout_plans" DROP COLUMN "isDeleted";
