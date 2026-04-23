-- Convert training_sessions.type, training_sessions.status, and
-- session_bookings.status from untyped String columns to proper PostgreSQL enums.
-- This enforces valid values at the database level and enables Prisma enum typing.

CREATE TYPE "TrainingSessionType"   AS ENUM ('GROUP_CLASS', 'ONE_ON_ONE', 'WORKSHOP');
CREATE TYPE "TrainingSessionStatus" AS ENUM ('SCHEDULED', 'CANCELLED', 'COMPLETED');
CREATE TYPE "SessionBookingStatus"  AS ENUM ('CONFIRMED', 'CANCELLED', 'ATTENDED', 'NO_SHOW');

ALTER TABLE "training_sessions"
  ALTER COLUMN "type"   TYPE "TrainingSessionType"   USING "type"::"TrainingSessionType",
  ALTER COLUMN "status" TYPE "TrainingSessionStatus" USING "status"::"TrainingSessionStatus";

ALTER TABLE "session_bookings"
  ALTER COLUMN "status" TYPE "SessionBookingStatus" USING "status"::"SessionBookingStatus";
