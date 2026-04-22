/*
  Warnings:

  - A unique constraint covering the columns `[userId,idempotencyKey]` on the table `food_logs` will be added. If there are existing duplicate values, this will fail.
  - A unique constraint covering the columns `[userId,idempotencyKey]` on the table `workout_history` will be added. If there are existing duplicate values, this will fail.

*/
-- AlterTable
ALTER TABLE "food_logs" ADD COLUMN     "idempotencyKey" TEXT;

-- AlterTable
ALTER TABLE "master_meals" ADD COLUMN     "dayOfWeek" "DayOfWeek";

-- AlterTable
ALTER TABLE "workout_history" ADD COLUMN     "idempotencyKey" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "food_logs_userId_idempotencyKey_key" ON "food_logs"("userId", "idempotencyKey");

-- CreateIndex
CREATE UNIQUE INDEX "workout_history_userId_idempotencyKey_key" ON "workout_history"("userId", "idempotencyKey");
