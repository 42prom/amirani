-- Allow PointEvents to exist without a room (global/solo user events).
-- Previously roomId and membershipId were NOT NULL, blocking point awards
-- for users who have no active room memberships.

-- Drop the old Cascade FK (will be replaced with SetNull-compatible nullable FK)
ALTER TABLE "point_events" DROP CONSTRAINT IF EXISTS "point_events_membershipId_fkey";

-- Make columns nullable
ALTER TABLE "point_events" ALTER COLUMN "roomId"       DROP NOT NULL;
ALTER TABLE "point_events" ALTER COLUMN "membershipId" DROP NOT NULL;

-- Recreate FK with SetNull so deleting a membership nullifies the event link
-- but preserves the audit trail (event still counted in user total points).
ALTER TABLE "point_events"
  ADD CONSTRAINT "point_events_membershipId_fkey"
  FOREIGN KEY ("membershipId") REFERENCES "room_memberships"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;
