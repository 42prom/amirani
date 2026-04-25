-- Add capacity, schedule, and contact fields to branches
ALTER TABLE branches ADD COLUMN IF NOT EXISTS city TEXT;
ALTER TABLE branches ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE branches ADD COLUMN IF NOT EXISTS "maxCapacity" INTEGER NOT NULL DEFAULT 50;
ALTER TABLE branches ADD COLUMN IF NOT EXISTS "openTime" TEXT;
ALTER TABLE branches ADD COLUMN IF NOT EXISTS "closeTime" TEXT;
