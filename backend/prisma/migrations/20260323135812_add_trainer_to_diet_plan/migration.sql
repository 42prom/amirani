/*
  Warnings:

  - You are about to drop the column `googleAndroidClientId` on the `oauth_config` table. All the data in the column will be lost.
  - You are about to drop the column `googleIosClientId` on the `oauth_config` table. All the data in the column will be lost.
  - You are about to drop the column `googleWebClientId` on the `oauth_config` table. All the data in the column will be lost.

*/
-- AlterTable
ALTER TABLE "diet_plans" ADD COLUMN     "trainerId" TEXT;

-- AlterTable
ALTER TABLE "oauth_config" DROP COLUMN "googleAndroidClientId",
DROP COLUMN "googleIosClientId",
DROP COLUMN "googleWebClientId";

-- AddForeignKey
ALTER TABLE "diet_plans" ADD CONSTRAINT "diet_plans_trainerId_fkey" FOREIGN KEY ("trainerId") REFERENCES "trainer_profiles"("id") ON DELETE SET NULL ON UPDATE CASCADE;
