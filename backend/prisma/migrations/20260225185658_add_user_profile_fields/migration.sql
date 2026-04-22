-- AlterTable
ALTER TABLE "users" ADD COLUMN     "address" TEXT,
ADD COLUMN     "dob" TEXT,
ADD COLUMN     "firstName" TEXT,
ADD COLUMN     "gender" TEXT,
ADD COLUMN     "height" TEXT,
ADD COLUMN     "idPhotoUrl" TEXT,
ADD COLUMN     "lastName" TEXT,
ADD COLUMN     "medicalConditions" TEXT,
ADD COLUMN     "noMedicalConditions" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "personalNumber" TEXT,
ADD COLUMN     "weight" TEXT;
