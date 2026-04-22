-- MealLog table: persists which meal a user marked as consumed on a given date.
-- refId holds Meal.id (literal) or MasterMeal.id (AI/template virtual meals).
CREATE TABLE IF NOT EXISTS "meal_logs" (
  "id"       TEXT NOT NULL,
  "userId"   TEXT NOT NULL,
  "refId"    TEXT NOT NULL,
  "date"     DATE NOT NULL,
  "loggedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "meal_logs_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "meal_logs_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "meal_logs_userId_refId_date_key" ON "meal_logs"("userId", "refId", "date");
CREATE INDEX IF NOT EXISTS "meal_logs_userId_date_idx" ON "meal_logs"("userId", "date");
