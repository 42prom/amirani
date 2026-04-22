-- Phase 4: Performance indexes

-- Attendance: composite lookup used by check-in dedup (serializable transaction)
CREATE INDEX IF NOT EXISTS "attendances_userId_gymId_idx" ON "attendances"("userId", "gymId");

-- Notifications: dedup query in scheduler uses (userId, type, createdAt DESC)
CREATE INDEX IF NOT EXISTS "notifications_userId_type_createdAt_idx" ON "notifications"("userId", "type", "createdAt" DESC);
