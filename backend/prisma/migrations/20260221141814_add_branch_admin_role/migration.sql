-- AlterEnum
ALTER TYPE "Role" ADD VALUE 'BRANCH_ADMIN';

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "managedGymId" TEXT;

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_managedGymId_fkey" FOREIGN KEY ("managedGymId") REFERENCES "gyms"("id") ON DELETE SET NULL ON UPDATE CASCADE;
