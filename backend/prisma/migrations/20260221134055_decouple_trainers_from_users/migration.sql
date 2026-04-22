/*
  Warnings:

  - Added the required column `fullName` to the `trainer_profiles` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE "trainer_profiles" ADD COLUMN     "age" INTEGER,
ADD COLUMN     "avatarUrl" TEXT,
ADD COLUMN     "email" TEXT,
ADD COLUMN     "fullName" TEXT NOT NULL,
ALTER COLUMN "userId" DROP NOT NULL;
