-- CreateTable: Reward
CREATE TABLE "rewards" (
    "id"          TEXT NOT NULL,
    "gymId"       TEXT,
    "name"        TEXT NOT NULL,
    "description" TEXT,
    "imageUrl"    TEXT,
    "pointsCost"  INTEGER NOT NULL,
    "stock"       INTEGER,
    "isActive"    BOOLEAN NOT NULL DEFAULT true,
    "expiresAt"   TIMESTAMP(3),
    "createdAt"   TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt"   TIMESTAMP(3) NOT NULL,

    CONSTRAINT "rewards_pkey" PRIMARY KEY ("id")
);

-- CreateTable: RewardRedemption
CREATE TABLE "reward_redemptions" (
    "id"          TEXT NOT NULL,
    "userId"      TEXT NOT NULL,
    "rewardId"    TEXT NOT NULL,
    "pointsSpent" INTEGER NOT NULL,
    "redeemedAt"  TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "status"      TEXT NOT NULL DEFAULT 'PENDING',

    CONSTRAINT "reward_redemptions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "rewards_gymId_isActive_idx" ON "rewards"("gymId", "isActive");

-- CreateIndex
CREATE INDEX "reward_redemptions_userId_redeemedAt_idx" ON "reward_redemptions"("userId", "redeemedAt" DESC);

-- CreateIndex
CREATE INDEX "reward_redemptions_rewardId_idx" ON "reward_redemptions"("rewardId");

-- AddForeignKey: RewardRedemption → User
ALTER TABLE "reward_redemptions" ADD CONSTRAINT "reward_redemptions_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey: RewardRedemption → Reward
ALTER TABLE "reward_redemptions" ADD CONSTRAINT "reward_redemptions_rewardId_fkey"
    FOREIGN KEY ("rewardId") REFERENCES "rewards"("id") ON UPDATE CASCADE;
