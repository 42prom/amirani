-- Add REFERRAL to PointSourceType enum
DO $$ BEGIN
    ALTER TYPE "PointSourceType" ADD VALUE 'REFERRAL';
EXCEPTION WHEN duplicate_object THEN null;
END $$;

-- Referral codes (one per user)
CREATE TABLE IF NOT EXISTS referral_codes (
  id            TEXT        NOT NULL PRIMARY KEY,
  code          TEXT        NOT NULL UNIQUE,
  "ownerId"     TEXT        NOT NULL UNIQUE,
  "usedCount"   INTEGER     NOT NULL DEFAULT 0,
  "pointsEarned" INTEGER    NOT NULL DEFAULT 0,
  "createdAt"   TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "referral_codes_ownerId_fkey" FOREIGN KEY ("ownerId") REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS "referral_codes_code_idx" ON referral_codes(code);

-- Referral uses (one per new user — enforced by UNIQUE on newUserId)
CREATE TABLE IF NOT EXISTS referral_uses (
  id          TEXT        NOT NULL PRIMARY KEY,
  "codeId"    TEXT        NOT NULL,
  "newUserId" TEXT        NOT NULL UNIQUE,
  "joinedAt"  TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "referral_uses_codeId_fkey"   FOREIGN KEY ("codeId")    REFERENCES referral_codes(id),
  CONSTRAINT "referral_uses_newUserId_fkey" FOREIGN KEY ("newUserId") REFERENCES users(id)
);
