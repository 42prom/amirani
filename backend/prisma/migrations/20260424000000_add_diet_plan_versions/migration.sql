-- DietPlanVersion: snapshot storage for diet plan history and rollback.
-- Mirrors workout_plan_versions in structure.
CREATE TABLE IF NOT EXISTS "diet_plan_versions" (
    "id"         TEXT NOT NULL,
    "dietPlanId" TEXT NOT NULL,
    "version"    INTEGER NOT NULL,
    "data"       JSONB NOT NULL,
    "createdAt"  TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "diet_plan_versions_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "diet_plan_versions_dietPlanId_version_key"
    ON "diet_plan_versions"("dietPlanId", "version");

ALTER TABLE "diet_plan_versions"
    ADD CONSTRAINT "diet_plan_versions_dietPlanId_fkey"
    FOREIGN KEY ("dietPlanId") REFERENCES "diet_plans"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
