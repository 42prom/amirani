/*
  Warnings:

  - You are about to drop the column `allowsDoorAccess` on the `subscription_plans` table. All the data in the column will be lost.
  - You are about to drop the column `durationDays` on the `subscription_plans` table. All the data in the column will be lost.
  - You are about to drop the column `iconUrl` on the `subscription_plans` table. All the data in the column will be lost.
  - You are about to drop the column `imageUrl` on the `subscription_plans` table. All the data in the column will be lost.
  - You are about to drop the column `includesTrainer` on the `subscription_plans` table. All the data in the column will be lost.
  - You are about to drop the column `priceMonthly` on the `subscription_plans` table. All the data in the column will be lost.
  - You are about to drop the column `priceYearly` on the `subscription_plans` table. All the data in the column will be lost.
  - You are about to drop the column `trainerSessionsPerMonth` on the `subscription_plans` table. All the data in the column will be lost.
  - Added the required column `price` to the `subscription_plans` table without a default value. This is not possible if the table is not empty.

*/
-- CreateEnum
CREATE TYPE "SaaSSubscriptionStatus" AS ENUM ('TRIAL', 'ACTIVE', 'PAST_DUE', 'OFF');

-- CreateEnum
CREATE TYPE "DifficultyLevel" AS ENUM ('BEGINNER', 'INTERMEDIATE', 'ADVANCED');

-- CreateEnum
CREATE TYPE "ExerciseType" AS ENUM ('STRENGTH', 'CARDIO', 'FLEXIBILITY', 'MOBILITY');

-- CreateEnum
CREATE TYPE "CompletionStatus" AS ENUM ('PENDING', 'IN_PROGRESS', 'COMPLETED', 'MISSED');

-- CreateEnum
CREATE TYPE "ChallengeType" AS ENUM ('STREAK', 'MACRO_GOAL', 'STEP_GOAL', 'WORKOUT_COMPLETION', 'HYDRATION');

-- AlterTable
ALTER TABLE "platform_config" ADD COLUMN     "currency" TEXT NOT NULL DEFAULT 'usd',
ADD COLUMN     "defaultTrialDays" INTEGER NOT NULL DEFAULT 14,
ADD COLUMN     "pricePerBranch" DECIMAL(10,2) NOT NULL DEFAULT 0.00;

-- AlterTable
ALTER TABLE "subscription_plans" DROP COLUMN "allowsDoorAccess",
DROP COLUMN "durationDays",
DROP COLUMN "iconUrl",
DROP COLUMN "imageUrl",
DROP COLUMN "includesTrainer",
DROP COLUMN "priceMonthly",
DROP COLUMN "priceYearly",
DROP COLUMN "trainerSessionsPerMonth",
ADD COLUMN     "durationUnit" TEXT NOT NULL DEFAULT 'days',
ADD COLUMN     "durationValue" INTEGER NOT NULL DEFAULT 30,
ADD COLUMN     "price" DECIMAL(10,2) NOT NULL;

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "saasNextBillingDate" TIMESTAMP(3),
ADD COLUMN     "saasSubscriptionStatus" "SaaSSubscriptionStatus" NOT NULL DEFAULT 'OFF',
ADD COLUMN     "saasTrialEndsAt" TIMESTAMP(3);

-- CreateTable
CREATE TABLE "workout_plans" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "difficulty" "DifficultyLevel" NOT NULL DEFAULT 'BEGINNER',
    "isAIGenerated" BOOLEAN NOT NULL DEFAULT false,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "startDate" TIMESTAMP(3),
    "endDate" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "userId" TEXT NOT NULL,
    "trainerId" TEXT,

    CONSTRAINT "workout_plans_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "workout_routines" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "dayOfWeek" "DayOfWeek",
    "orderIndex" INTEGER NOT NULL DEFAULT 0,
    "estimatedMinutes" INTEGER NOT NULL DEFAULT 45,
    "planId" TEXT NOT NULL,

    CONSTRAINT "workout_routines_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "exercise_sets" (
    "id" TEXT NOT NULL,
    "exerciseName" TEXT NOT NULL,
    "exerciseType" "ExerciseType" NOT NULL DEFAULT 'STRENGTH',
    "targetSets" INTEGER NOT NULL DEFAULT 3,
    "targetReps" INTEGER,
    "targetDuration" INTEGER,
    "targetWeight" DECIMAL(10,2),
    "restSeconds" INTEGER NOT NULL DEFAULT 60,
    "orderIndex" INTEGER NOT NULL DEFAULT 0,
    "mediaUrl" TEXT,
    "routineId" TEXT NOT NULL,

    CONSTRAINT "exercise_sets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "workout_history" (
    "id" TEXT NOT NULL,
    "completedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "durationMinutes" INTEGER NOT NULL,
    "totalVolume" DECIMAL(10,2),
    "notes" TEXT,
    "userId" TEXT NOT NULL,
    "routineId" TEXT,

    CONSTRAINT "workout_history_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "completed_sets" (
    "id" TEXT NOT NULL,
    "exerciseName" TEXT NOT NULL,
    "actualSets" INTEGER NOT NULL,
    "actualReps" INTEGER,
    "actualDuration" INTEGER,
    "actualWeight" DECIMAL(10,2),
    "historyId" TEXT NOT NULL,

    CONSTRAINT "completed_sets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "diet_plans" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "isAIGenerated" BOOLEAN NOT NULL DEFAULT false,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "targetCalories" INTEGER NOT NULL,
    "targetProtein" INTEGER NOT NULL,
    "targetCarbs" INTEGER NOT NULL,
    "targetFats" INTEGER NOT NULL,
    "targetWater" DECIMAL(4,1) NOT NULL DEFAULT 3.0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "userId" TEXT NOT NULL,

    CONSTRAINT "diet_plans_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "meals" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "timeOfDay" TEXT,
    "totalCalories" INTEGER NOT NULL,
    "protein" INTEGER NOT NULL,
    "carbs" INTEGER NOT NULL,
    "fats" INTEGER NOT NULL,
    "items" JSONB,
    "mediaUrl" TEXT,
    "planId" TEXT NOT NULL,

    CONSTRAINT "meals_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "daily_progress" (
    "id" TEXT NOT NULL,
    "date" DATE NOT NULL,
    "score" INTEGER NOT NULL DEFAULT 0,
    "caloriesConsumed" INTEGER NOT NULL DEFAULT 0,
    "proteinConsumed" INTEGER NOT NULL DEFAULT 0,
    "carbsConsumed" INTEGER NOT NULL DEFAULT 0,
    "fatsConsumed" INTEGER NOT NULL DEFAULT 0,
    "waterConsumed" DECIMAL(4,1) NOT NULL DEFAULT 0.0,
    "stepsTaken" INTEGER NOT NULL DEFAULT 0,
    "activeMinutes" INTEGER NOT NULL DEFAULT 0,
    "tasksTotal" INTEGER NOT NULL DEFAULT 0,
    "tasksCompleted" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "userId" TEXT NOT NULL,

    CONSTRAINT "daily_progress_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_challenges" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "type" "ChallengeType" NOT NULL,
    "targetValue" INTEGER NOT NULL,
    "currentValue" INTEGER NOT NULL DEFAULT 0,
    "status" "CompletionStatus" NOT NULL DEFAULT 'IN_PROGRESS',
    "rewardPoints" INTEGER NOT NULL DEFAULT 50,
    "startDate" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "endDate" TIMESTAMP(3) NOT NULL,
    "isAIGenerated" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "userId" TEXT NOT NULL,

    CONSTRAINT "user_challenges_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "daily_progress_userId_date_key" ON "daily_progress"("userId", "date");

-- AddForeignKey
ALTER TABLE "workout_plans" ADD CONSTRAINT "workout_plans_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "workout_plans" ADD CONSTRAINT "workout_plans_trainerId_fkey" FOREIGN KEY ("trainerId") REFERENCES "trainer_profiles"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "workout_routines" ADD CONSTRAINT "workout_routines_planId_fkey" FOREIGN KEY ("planId") REFERENCES "workout_plans"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "exercise_sets" ADD CONSTRAINT "exercise_sets_routineId_fkey" FOREIGN KEY ("routineId") REFERENCES "workout_routines"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "workout_history" ADD CONSTRAINT "workout_history_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "workout_history" ADD CONSTRAINT "workout_history_routineId_fkey" FOREIGN KEY ("routineId") REFERENCES "workout_routines"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "completed_sets" ADD CONSTRAINT "completed_sets_historyId_fkey" FOREIGN KEY ("historyId") REFERENCES "workout_history"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "diet_plans" ADD CONSTRAINT "diet_plans_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "meals" ADD CONSTRAINT "meals_planId_fkey" FOREIGN KEY ("planId") REFERENCES "diet_plans"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "daily_progress" ADD CONSTRAINT "daily_progress_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_challenges" ADD CONSTRAINT "user_challenges_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
