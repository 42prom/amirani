-- Remove hard unique constraint that blocked re-enrollment after expiry/cancellation.
-- Replace with a partial unique index that only enforces uniqueness for non-terminal
-- memberships (ACTIVE, PENDING, FROZEN). EXPIRED and CANCELLED records are inert,
-- allowing the gym to re-enroll a returning member without losing history.
DROP INDEX IF EXISTS "gym_memberships_userId_gymId_key";

CREATE UNIQUE INDEX IF NOT EXISTS "gym_memberships_active_unique"
    ON "gym_memberships" ("userId", "gymId")
    WHERE status NOT IN ('EXPIRED', 'CANCELLED');
