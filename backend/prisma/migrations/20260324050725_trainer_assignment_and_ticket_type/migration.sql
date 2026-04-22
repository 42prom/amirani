-- AlterTable
ALTER TABLE "support_tickets" ADD COLUMN     "ticketType" TEXT NOT NULL DEFAULT 'SUPPORT',
ADD COLUMN     "trainerId" TEXT;

-- CreateTable
CREATE TABLE "trainer_assignment_requests" (
    "id" TEXT NOT NULL,
    "gymId" TEXT NOT NULL,
    "memberId" TEXT NOT NULL,
    "trainerId" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "message" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "trainer_assignment_requests_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "trainer_assignment_requests_memberId_gymId_status_idx" ON "trainer_assignment_requests"("memberId", "gymId", "status");

-- CreateIndex
CREATE INDEX "trainer_assignment_requests_trainerId_status_idx" ON "trainer_assignment_requests"("trainerId", "status");

-- CreateIndex
CREATE INDEX "trainer_assignment_requests_gymId_idx" ON "trainer_assignment_requests"("gymId");

-- CreateIndex
CREATE INDEX "support_tickets_gymId_ticketType_idx" ON "support_tickets"("gymId", "ticketType");

-- CreateIndex
CREATE INDEX "support_tickets_trainerId_idx" ON "support_tickets"("trainerId");

-- AddForeignKey
ALTER TABLE "support_tickets" ADD CONSTRAINT "support_tickets_trainerId_fkey" FOREIGN KEY ("trainerId") REFERENCES "trainer_profiles"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "trainer_assignment_requests" ADD CONSTRAINT "trainer_assignment_requests_gymId_fkey" FOREIGN KEY ("gymId") REFERENCES "gyms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "trainer_assignment_requests" ADD CONSTRAINT "trainer_assignment_requests_memberId_fkey" FOREIGN KEY ("memberId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "trainer_assignment_requests" ADD CONSTRAINT "trainer_assignment_requests_trainerId_fkey" FOREIGN KEY ("trainerId") REFERENCES "trainer_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;
