-- AlterEnum
ALTER TYPE "FoodSource" ADD VALUE 'TRAINER';

-- AlterTable
ALTER TABLE "food_items" ADD COLUMN     "createdBy" TEXT;

-- CreateIndex
CREATE INDEX "food_items_createdBy_idx" ON "food_items"("createdBy");
