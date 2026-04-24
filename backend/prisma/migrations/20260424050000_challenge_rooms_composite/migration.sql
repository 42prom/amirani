-- CreateTable: RoomChallenge
CREATE TABLE "room_challenges" (
    "id"           TEXT NOT NULL,
    "roomId"       TEXT NOT NULL,
    "title"        TEXT NOT NULL,
    "description"  TEXT,
    "targetValue"  INTEGER NOT NULL,
    "unit"         TEXT NOT NULL,
    "pointsReward" INTEGER NOT NULL DEFAULT 25,
    "startDate"    TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "endDate"      TIMESTAMP(3),
    "isActive"     BOOLEAN NOT NULL DEFAULT true,
    "createdAt"    TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "room_challenges_pkey" PRIMARY KEY ("id")
);

-- CreateTable: ChallengeProgress
CREATE TABLE "challenge_progress" (
    "id"           TEXT NOT NULL,
    "challengeId"  TEXT NOT NULL,
    "userId"       TEXT NOT NULL,
    "currentValue" INTEGER NOT NULL DEFAULT 0,
    "completed"    BOOLEAN NOT NULL DEFAULT false,
    "completedAt"  TIMESTAMP(3),
    "createdAt"    TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt"    TIMESTAMP(3) NOT NULL,

    CONSTRAINT "challenge_progress_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "room_challenges_roomId_isActive_idx" ON "room_challenges"("roomId", "isActive");

-- CreateIndex
CREATE UNIQUE INDEX "challenge_progress_challengeId_userId_key" ON "challenge_progress"("challengeId", "userId");

-- CreateIndex
CREATE INDEX "challenge_progress_userId_idx" ON "challenge_progress"("userId");

-- AddForeignKey: RoomChallenge → ProgressRoom
ALTER TABLE "room_challenges" ADD CONSTRAINT "room_challenges_roomId_fkey"
    FOREIGN KEY ("roomId") REFERENCES "progress_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey: ChallengeProgress → RoomChallenge
ALTER TABLE "challenge_progress" ADD CONSTRAINT "challenge_progress_challengeId_fkey"
    FOREIGN KEY ("challengeId") REFERENCES "room_challenges"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey: ChallengeProgress → User
ALTER TABLE "challenge_progress" ADD CONSTRAINT "challenge_progress_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
