-- Phase 1: Enchantment — Controlled Ingredients, Exercise Filtering,
-- Smart Substitution, Hybrid System, Trainer Contribution & Super Admin Review,
-- Country field on User.
-- Migration created: 2026-04-24

-- ─── 1. ItemStatus enum ──────────────────────────────────────────────────────
CREATE TYPE "ItemStatus" AS ENUM ('PENDING', 'UNDER_REVIEW', 'APPROVED', 'REJECTED');

-- ─── 2. User: country field ──────────────────────────────────────────────────
ALTER TABLE "users" ADD COLUMN "country" TEXT;

-- ─── 3. FoodItem: rename createdBy → createdById ─────────────────────────────
-- Uses RENAME to preserve existing trainerUserId data (no data loss).
ALTER TABLE "food_items" RENAME COLUMN "created_by" TO "created_by_id";

-- ─── 4. FoodItem: new columns ─────────────────────────────────────────────────
ALTER TABLE "food_items"
  ADD COLUMN "status"             "ItemStatus"  NOT NULL DEFAULT 'PENDING',
  ADD COLUMN "image_url"          TEXT,
  ADD COLUMN "icon_url"           TEXT,
  ADD COLUMN "country_codes"      TEXT[]        NOT NULL DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN "seasonality"        TEXT[]        NOT NULL DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN "availability_score" INTEGER       NOT NULL DEFAULT 50,
  ADD COLUMN "allergy_tags"       TEXT[]        NOT NULL DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN "substitution_group" TEXT;

-- Null out any orphaned createdById values before adding FK
-- (ensures existing trainer IDs that were deleted won't break the constraint)
UPDATE "food_items"
SET "created_by_id" = NULL
WHERE "created_by_id" IS NOT NULL
  AND "created_by_id" NOT IN (SELECT "id" FROM "users");

-- Add FK: food_items.created_by_id → users.id
ALTER TABLE "food_items"
  ADD CONSTRAINT "food_items_created_by_id_fkey"
  FOREIGN KEY ("created_by_id") REFERENCES "users"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;

-- ─── 5. Approve all pre-existing food items (they were already in use) ────────
UPDATE "food_items" SET "status" = 'APPROVED';

-- ─── 6. ExerciseLibrary: new columns ─────────────────────────────────────────
ALTER TABLE "exercise_library"
  ADD COLUMN "status"        "ItemStatus"  NOT NULL DEFAULT 'PENDING',
  ADD COLUMN "location"      TEXT[]        NOT NULL DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN "fitness_goals" TEXT[]        NOT NULL DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN "created_by_id" TEXT;

-- FK: exercise_library.created_by_id → users.id
ALTER TABLE "exercise_library"
  ADD CONSTRAINT "exercise_library_created_by_id_fkey"
  FOREIGN KEY ("created_by_id") REFERENCES "users"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;

-- ─── 7. Approve all pre-existing exercises ───────────────────────────────────
UPDATE "exercise_library" SET "status" = 'APPROVED';

-- ─── 8. SubstitutionMap table ─────────────────────────────────────────────────
CREATE TABLE "substitution_maps" (
  "id"                TEXT        NOT NULL,
  "food_item_id"      TEXT        NOT NULL,
  "substitute_id"     TEXT        NOT NULL,
  "cultural_score"    INTEGER     NOT NULL DEFAULT 50,
  "nutritional_score" INTEGER     NOT NULL DEFAULT 50,
  "country_codes"     TEXT[]      NOT NULL DEFAULT ARRAY[]::TEXT[],
  "is_active"         BOOLEAN     NOT NULL DEFAULT true,
  "created_at"        TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "substitution_maps_pkey"
    PRIMARY KEY ("id"),
  CONSTRAINT "substitution_maps_food_item_id_substitute_id_key"
    UNIQUE ("food_item_id", "substitute_id"),
  CONSTRAINT "substitution_maps_food_item_id_fkey"
    FOREIGN KEY ("food_item_id") REFERENCES "food_items"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "substitution_maps_substitute_id_fkey"
    FOREIGN KEY ("substitute_id") REFERENCES "food_items"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "substitution_maps_food_item_id_idx" ON "substitution_maps"("food_item_id");

-- ─── 9. HybridTemplate table ─────────────────────────────────────────────────
CREATE TABLE "hybrid_templates" (
  "id"                  TEXT         NOT NULL,
  "name"                TEXT         NOT NULL,
  "description"         TEXT,
  "country_codes"       TEXT[]       NOT NULL DEFAULT ARRAY[]::TEXT[],
  "diet_types"          TEXT[]       NOT NULL DEFAULT ARRAY[]::TEXT[],
  "fitness_goals"       TEXT[]       NOT NULL DEFAULT ARRAY[]::TEXT[],
  "fitness_levels"      TEXT[]       NOT NULL DEFAULT ARRAY[]::TEXT[],
  "status"              "ItemStatus" NOT NULL DEFAULT 'APPROVED',
  "diet_template_id"    TEXT,
  "workout_template_id" TEXT,
  "is_ai_generated"     BOOLEAN      NOT NULL DEFAULT false,
  "creator_id"          TEXT,
  "created_at"          TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at"          TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "hybrid_templates_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "hybrid_templates_status_idx"        ON "hybrid_templates"("status");
CREATE INDEX "hybrid_templates_country_codes_idx" ON "hybrid_templates" USING GIN("country_codes");
CREATE INDEX "hybrid_templates_fitness_goals_idx" ON "hybrid_templates" USING GIN("fitness_goals");

-- ─── 10. Additional indexes for FoodItem ─────────────────────────────────────
CREATE INDEX "food_items_status_idx"             ON "food_items"("status");
CREATE INDEX "food_items_availability_score_idx" ON "food_items"("availability_score");
CREATE INDEX "food_items_substitution_group_idx" ON "food_items"("substitution_group");
CREATE INDEX "food_items_country_codes_idx"      ON "food_items" USING GIN("country_codes");
CREATE INDEX "food_items_allergy_tags_idx"       ON "food_items" USING GIN("allergy_tags");

-- ─── 11. Additional indexes for ExerciseLibrary ──────────────────────────────
CREATE INDEX "exercise_library_status_idx"   ON "exercise_library"("status");
CREATE INDEX "exercise_library_location_idx" ON "exercise_library" USING GIN("location");
