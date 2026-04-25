-- Deduplicate: keep one row per userId+date (MIN id wins) before adding constraint.
-- Safe to run on empty or production tables.
DELETE FROM user_weight_history
WHERE id NOT IN (
  SELECT MIN(id)
  FROM user_weight_history
  GROUP BY "userId", date
);

-- Add unique constraint (Prisma-named).
CREATE UNIQUE INDEX IF NOT EXISTS "user_weight_history_userId_date_key"
  ON user_weight_history ("userId", date);
