/*
  Warnings:

  - You are about to drop the column `items` on the `meals` table. All the data in the column will be lost.
  - The `weight` column on the `users` table would be dropped and recreated. This will lead to data loss if there is data in the column.
  - The `targetWeightKg` column on the `users` table would be dropped and recreated. This will lead to data loss if there is data in the column.

*/
-- AlterTable
ALTER TABLE "daily_progress" ADD COLUMN     "isDeleted" BOOLEAN NOT NULL DEFAULT false;

-- AlterTable
ALTER TABLE "diet_plans" ADD COLUMN     "isDeleted" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "isPublished" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "masterTemplateId" TEXT;

-- AlterTable
ALTER TABLE "exercise_library" ADD COLUMN     "metValue" DOUBLE PRECISION NOT NULL DEFAULT 3.0;

-- AlterTable
ALTER TABLE "meals" DROP COLUMN "items",
ADD COLUMN     "instructions" TEXT,
ADD COLUMN     "isReminderEnabled" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN     "notificationTime" TEXT;

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "lastActivityAt" DATE,
ADD COLUMN     "streakDays" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "timezone" TEXT DEFAULT 'UTC',
ADD COLUMN     "totalPoints" INTEGER NOT NULL DEFAULT 0,
DROP COLUMN "weight",
ADD COLUMN     "weight" DECIMAL(10,2),
DROP COLUMN "targetWeightKg",
ADD COLUMN     "targetWeightKg" DECIMAL(10,2);

-- AlterTable
ALTER TABLE "workout_history" ADD COLUMN     "caloriesBurned" DECIMAL(10,2);

-- AlterTable
ALTER TABLE "workout_plans" ADD COLUMN     "isDeleted" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "masterTemplateId" TEXT;

-- CreateTable
CREATE TABLE "master_workout_templates" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "difficulty" "DifficultyLevel" NOT NULL DEFAULT 'BEGINNER',
    "isAIGenerated" BOOLEAN NOT NULL DEFAULT false,
    "creatorId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "master_workout_templates_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "master_diet_templates" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "targetCalories" INTEGER NOT NULL,
    "targetProtein" INTEGER NOT NULL,
    "targetCarbs" INTEGER NOT NULL,
    "targetFats" INTEGER NOT NULL,
    "targetWater" DECIMAL(4,1) NOT NULL DEFAULT 3.0,
    "isAIGenerated" BOOLEAN NOT NULL DEFAULT false,
    "creatorId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "master_diet_templates_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "master_meals" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "orderIndex" INTEGER NOT NULL DEFAULT 0,
    "timeOfDay" TEXT,
    "instructions" TEXT,
    "mediaUrl" TEXT,
    "templateId" TEXT NOT NULL,
    "notificationTime" TEXT,
    "isReminderEnabled" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "master_meals_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "master_meal_ingredients" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "amount" DECIMAL(8,2) NOT NULL,
    "unit" TEXT NOT NULL,
    "calories" INTEGER NOT NULL,
    "protein" DECIMAL(8,2) NOT NULL,
    "carbs" DECIMAL(8,2) NOT NULL,
    "fats" DECIMAL(8,2) NOT NULL,
    "mealId" TEXT NOT NULL,

    CONSTRAINT "master_meal_ingredients_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "meal_ingredients" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "amount" DECIMAL(8,2) NOT NULL,
    "unit" TEXT NOT NULL,
    "calories" INTEGER NOT NULL,
    "protein" DECIMAL(8,2) NOT NULL,
    "carbs" DECIMAL(8,2) NOT NULL,
    "fats" DECIMAL(8,2) NOT NULL,
    "mealId" TEXT NOT NULL,

    CONSTRAINT "meal_ingredients_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "master_workout_routines" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "dayOfWeek" "DayOfWeek",
    "orderIndex" INTEGER NOT NULL DEFAULT 0,
    "estimatedMinutes" INTEGER NOT NULL DEFAULT 45,
    "templateId" TEXT NOT NULL,

    CONSTRAINT "master_workout_routines_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "master_exercise_sets" (
    "id" TEXT NOT NULL,
    "exerciseName" TEXT NOT NULL,
    "exerciseLibraryId" TEXT,
    "exerciseType" "ExerciseType" NOT NULL DEFAULT 'STRENGTH',
    "targetSets" INTEGER NOT NULL DEFAULT 3,
    "targetReps" INTEGER,
    "targetDuration" INTEGER,
    "targetWeight" DECIMAL(10,2),
    "restSeconds" INTEGER NOT NULL DEFAULT 60,
    "orderIndex" INTEGER NOT NULL DEFAULT 0,
    "rpe" INTEGER,
    "tempoEccentric" INTEGER,
    "tempoPause" INTEGER,
    "tempoConcentric" INTEGER,
    "progressionNote" TEXT,
    "routineId" TEXT NOT NULL,

    CONSTRAINT "master_exercise_sets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "plan_delta_overrides" (
    "id" TEXT NOT NULL,
    "workoutPlanId" TEXT NOT NULL,
    "masterRoutineId" TEXT,
    "masterExerciseSetId" TEXT,
    "mutationType" TEXT NOT NULL,
    "overriddenValues" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "plan_delta_overrides_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "master_exercise_sets_exerciseLibraryId_idx" ON "master_exercise_sets"("exerciseLibraryId");

-- CreateIndex
CREATE INDEX "plan_delta_overrides_workoutPlanId_idx" ON "plan_delta_overrides"("workoutPlanId");

-- AddForeignKey
ALTER TABLE "workout_plans" ADD CONSTRAINT "workout_plans_masterTemplateId_fkey" FOREIGN KEY ("masterTemplateId") REFERENCES "master_workout_templates"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "master_meals" ADD CONSTRAINT "master_meals_templateId_fkey" FOREIGN KEY ("templateId") REFERENCES "master_diet_templates"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "master_meal_ingredients" ADD CONSTRAINT "master_meal_ingredients_mealId_fkey" FOREIGN KEY ("mealId") REFERENCES "master_meals"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "meal_ingredients" ADD CONSTRAINT "meal_ingredients_mealId_fkey" FOREIGN KEY ("mealId") REFERENCES "meals"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "master_workout_routines" ADD CONSTRAINT "master_workout_routines_templateId_fkey" FOREIGN KEY ("templateId") REFERENCES "master_workout_templates"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "master_exercise_sets" ADD CONSTRAINT "master_exercise_sets_routineId_fkey" FOREIGN KEY ("routineId") REFERENCES "master_workout_routines"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "master_exercise_sets" ADD CONSTRAINT "master_exercise_sets_exerciseLibraryId_fkey" FOREIGN KEY ("exerciseLibraryId") REFERENCES "exercise_library"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "plan_delta_overrides" ADD CONSTRAINT "plan_delta_overrides_workoutPlanId_fkey" FOREIGN KEY ("workoutPlanId") REFERENCES "workout_plans"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "diet_plans" ADD CONSTRAINT "diet_plans_masterTemplateId_fkey" FOREIGN KEY ("masterTemplateId") REFERENCES "master_diet_templates"("id") ON DELETE SET NULL ON UPDATE CASCADE;
