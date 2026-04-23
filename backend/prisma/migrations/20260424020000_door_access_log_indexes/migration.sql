-- Indexes on door_access_logs for fast audit queries and per-user access history.
-- Both columns are already in the FK constraints but have no covering indexes for
-- range scans by accessTime, which is the primary ordering in admin reports.
CREATE INDEX IF NOT EXISTS "door_access_logs_userId_accessTime_idx"
    ON "door_access_logs" ("userId", "accessTime" DESC);

CREATE INDEX IF NOT EXISTS "door_access_logs_doorSystemId_accessTime_idx"
    ON "door_access_logs" ("doorSystemId", "accessTime" DESC);
