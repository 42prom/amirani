/*
  Warnings:

  - A unique constraint covering the columns `[registrationCode]` on the table `gyms` will be added. If there are existing duplicate values, this will fail.

*/
-- CreateEnum
CREATE TYPE "DepositStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

-- CreateEnum
CREATE TYPE "DepositType" AS ENUM ('CASH_ON_HAND', 'BANK_DEPOSIT');

-- CreateEnum
CREATE TYPE "GatewayProtocol" AS ENUM ('RELAY_HTTP', 'WIEGAND', 'OSDP_V2', 'ZKTECO_TCP', 'SALTO_OSDP', 'MQTT');

-- CreateEnum
CREATE TYPE "GatewayCmd" AS ENUM ('UNLOCK', 'LOCK', 'STATUS', 'ALARM');

-- CreateEnum
CREATE TYPE "CommandStatus" AS ENUM ('PENDING', 'SENT', 'EXECUTED', 'FAILED', 'EXPIRED');

-- CreateEnum
CREATE TYPE "CardType" AS ENUM ('RFID_125KHZ', 'NFC_MIFARE', 'NFC_DESFIRE', 'PHONE_HCE', 'WIEGAND_RAW');

-- CreateEnum
CREATE TYPE "MealType" AS ENUM ('BREAKFAST', 'LUNCH', 'DINNER', 'SNACK', 'PRE_WORKOUT', 'POST_WORKOUT');

-- CreateEnum
CREATE TYPE "FoodSource" AS ENUM ('NUTRITIONIX', 'OPEN_FOOD_FACTS', 'USER');

-- CreateEnum
CREATE TYPE "QrType" AS ENUM ('GYM_JOIN', 'DAILY_CHECKIN');

-- CreateEnum
CREATE TYPE "RecoverySource" AS ENUM ('APPLE_HEALTH', 'GOOGLE_HEALTH', 'MANUAL');

-- CreateEnum
CREATE TYPE "PointSourceType" AS ENUM ('WORKOUT', 'CHALLENGE', 'CHECKIN', 'STREAK_BONUS', 'MANUAL');

-- CreateEnum
CREATE TYPE "ExerciseMechanics" AS ENUM ('COMPOUND', 'ISOLATION');

-- CreateEnum
CREATE TYPE "ExerciseForce" AS ENUM ('PUSH', 'PULL', 'HINGE', 'SQUAT', 'CARRY', 'STATIC');

-- AlterEnum
ALTER TYPE "PaymentMethod" ADD VALUE 'TRANSFER';

-- AlterEnum
ALTER TYPE "SubscriptionStatus" ADD VALUE 'FROZEN';

-- AlterTable
ALTER TABLE "attendances" ADD COLUMN     "zoneId" TEXT;

-- AlterTable
ALTER TABLE "completed_sets" ADD COLUMN     "exerciseLibraryId" TEXT,
ADD COLUMN     "notes" TEXT,
ADD COLUMN     "rpe" INTEGER;

-- AlterTable
ALTER TABLE "exercise_sets" ADD COLUMN     "exerciseLibraryId" TEXT,
ADD COLUMN     "progressionNote" TEXT,
ADD COLUMN     "rpe" INTEGER,
ADD COLUMN     "tempoConcentric" INTEGER,
ADD COLUMN     "tempoEccentric" INTEGER,
ADD COLUMN     "tempoPause" INTEGER;

-- AlterTable
ALTER TABLE "gym_memberships" ADD COLUMN     "freezeReason" TEXT,
ADD COLUMN     "frozenAt" TIMESTAMP(3),
ADD COLUMN     "frozenUntil" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "gyms" ADD COLUMN     "qrSecret" TEXT,
ADD COLUMN     "registrationCode" TEXT,
ADD COLUMN     "themeColor" TEXT,
ADD COLUMN     "welcomeMessage" TEXT;

-- AlterTable
ALTER TABLE "meals" ADD COLUMN     "scheduledDate" DATE;

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "activeGymId" TEXT,
ADD COLUMN     "customPlatformFeePercent" DOUBLE PRECISION,
ADD COLUMN     "customPricePerBranch" DOUBLE PRECISION,
ADD COLUMN     "isLifetimeFree" BOOLEAN NOT NULL DEFAULT false;

-- AlterTable
ALTER TABLE "workout_routines" ADD COLUMN     "scheduledDate" DATE;

-- CreateTable
CREATE TABLE "hardware_gateways" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "gymId" TEXT NOT NULL,
    "apiKey" TEXT NOT NULL,
    "location" TEXT,
    "protocol" "GatewayProtocol" NOT NULL DEFAULT 'RELAY_HTTP',
    "config" JSONB,
    "isOnline" BOOLEAN NOT NULL DEFAULT false,
    "lastSeenAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "hardware_gateways_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "gateway_commands" (
    "id" TEXT NOT NULL,
    "gatewayId" TEXT NOT NULL,
    "doorId" TEXT,
    "command" "GatewayCmd" NOT NULL,
    "payload" JSONB,
    "status" "CommandStatus" NOT NULL DEFAULT 'PENDING',
    "triggeredBy" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "executedAt" TIMESTAMP(3),

    CONSTRAINT "gateway_commands_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "card_credentials" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "gymId" TEXT NOT NULL,
    "cardUid" TEXT NOT NULL,
    "facilityCode" INTEGER,
    "cardNumber" INTEGER,
    "cardType" "CardType" NOT NULL DEFAULT 'NFC_MIFARE',
    "label" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "card_credentials_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "deposits" (
    "id" TEXT NOT NULL,
    "amount" DECIMAL(10,2) NOT NULL,
    "type" "DepositType" NOT NULL,
    "status" "DepositStatus" NOT NULL DEFAULT 'PENDING',
    "reference" TEXT,
    "notes" TEXT,
    "currency" TEXT NOT NULL DEFAULT 'usd',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "gymId" TEXT NOT NULL,
    "submittedById" TEXT NOT NULL,
    "approvedById" TEXT,

    CONSTRAINT "deposits_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "oauth_config" (
    "id" TEXT NOT NULL DEFAULT 'singleton',
    "googleEnabled" BOOLEAN NOT NULL DEFAULT false,
    "googleClientId" TEXT,
    "googleClientSecret" TEXT,
    "appleEnabled" BOOLEAN NOT NULL DEFAULT false,
    "appleClientId" TEXT,
    "appleTeamId" TEXT,
    "appleKeyId" TEXT,
    "applePrivateKey" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "oauth_config_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "marketing_campaigns" (
    "id" TEXT NOT NULL,
    "gymId" TEXT NOT NULL,
    "createdById" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "subject" TEXT,
    "body" TEXT NOT NULL,
    "imageUrl" TEXT,
    "channels" TEXT[] DEFAULT ARRAY['PUSH', 'IN_APP']::TEXT[],
    "targetAudience" TEXT NOT NULL,
    "targetPlanId" TEXT,
    "status" TEXT NOT NULL DEFAULT 'DRAFT',
    "scheduledAt" TIMESTAMP(3),
    "sentAt" TIMESTAMP(3),
    "totalTargeted" INTEGER NOT NULL DEFAULT 0,
    "totalDelivered" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "marketing_campaigns_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "automation_rules" (
    "id" TEXT NOT NULL,
    "gymId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "trigger" TEXT NOT NULL,
    "subject" TEXT,
    "body" TEXT NOT NULL,
    "channels" TEXT[] DEFAULT ARRAY['PUSH', 'IN_APP']::TEXT[],
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "lastRunAt" TIMESTAMP(3),
    "totalFired" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "automation_rules_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "gym_announcements" (
    "id" TEXT NOT NULL,
    "gymId" TEXT NOT NULL,
    "authorId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "imageUrl" TEXT,
    "isPinned" BOOLEAN NOT NULL DEFAULT false,
    "targetAudience" TEXT NOT NULL DEFAULT 'ALL',
    "channels" TEXT[] DEFAULT ARRAY['PUSH', 'IN_APP']::TEXT[],
    "totalDelivered" INTEGER NOT NULL DEFAULT 0,
    "publishedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "gym_announcements_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "training_sessions" (
    "id" TEXT NOT NULL,
    "gymId" TEXT NOT NULL,
    "trainerId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "type" TEXT NOT NULL DEFAULT 'GROUP_CLASS',
    "startTime" TIMESTAMP(3) NOT NULL,
    "endTime" TIMESTAMP(3) NOT NULL,
    "maxCapacity" INTEGER NOT NULL DEFAULT 20,
    "location" TEXT,
    "status" TEXT NOT NULL DEFAULT 'SCHEDULED',
    "color" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "training_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "session_bookings" (
    "id" TEXT NOT NULL,
    "sessionId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'CONFIRMED',
    "bookedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "session_bookings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "support_tickets" (
    "id" TEXT NOT NULL,
    "gymId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "subject" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'OPEN',
    "priority" TEXT NOT NULL DEFAULT 'MEDIUM',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "support_tickets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ticket_messages" (
    "id" TEXT NOT NULL,
    "ticketId" TEXT NOT NULL,
    "senderId" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "isStaff" BOOLEAN NOT NULL DEFAULT false,
    "readAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ticket_messages_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "audit_logs" (
    "id" TEXT NOT NULL,
    "gymId" TEXT NOT NULL,
    "actorId" TEXT NOT NULL,
    "action" TEXT NOT NULL,
    "entity" TEXT NOT NULL,
    "entityId" TEXT,
    "label" TEXT NOT NULL,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "webhook_endpoints" (
    "id" TEXT NOT NULL,
    "gymId" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "secret" TEXT NOT NULL,
    "events" TEXT[],
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "webhook_endpoints_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "webhook_deliveries" (
    "id" TEXT NOT NULL,
    "endpointId" TEXT NOT NULL,
    "event" TEXT NOT NULL,
    "payload" JSONB NOT NULL,
    "statusCode" INTEGER,
    "responseBody" TEXT,
    "success" BOOLEAN NOT NULL DEFAULT false,
    "duration" INTEGER,
    "attemptedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "webhook_deliveries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "progress_rooms" (
    "id" TEXT NOT NULL,
    "gymId" TEXT NOT NULL,
    "creatorId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "metric" TEXT NOT NULL,
    "period" TEXT NOT NULL,
    "startDate" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "endDate" TIMESTAMP(3),
    "isPublic" BOOLEAN NOT NULL DEFAULT true,
    "inviteCode" TEXT NOT NULL,
    "maxMembers" INTEGER NOT NULL DEFAULT 30,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "progress_rooms_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "room_memberships" (
    "id" TEXT NOT NULL,
    "roomId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "totalPoints" INTEGER NOT NULL DEFAULT 0,
    "weeklyPoints" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "room_memberships_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "point_events" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "roomId" TEXT NOT NULL,
    "membershipId" TEXT NOT NULL,
    "sourceId" TEXT NOT NULL,
    "sourceType" "PointSourceType" NOT NULL,
    "delta" INTEGER NOT NULL,
    "reason" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "point_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "exercise_library" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "primaryMuscle" TEXT NOT NULL,
    "secondaryMuscles" TEXT[],
    "equipment" TEXT[],
    "difficulty" "DifficultyLevel" NOT NULL DEFAULT 'BEGINNER',
    "mechanics" "ExerciseMechanics" NOT NULL DEFAULT 'COMPOUND',
    "force" "ExerciseForce" NOT NULL DEFAULT 'PUSH',
    "videoUrl" TEXT,
    "cues" TEXT[],
    "commonMistakes" TEXT[],
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "exercise_library_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "food_items" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "brand" TEXT,
    "barcode" TEXT,
    "calories" DOUBLE PRECISION NOT NULL,
    "protein" DOUBLE PRECISION NOT NULL,
    "carbs" DOUBLE PRECISION NOT NULL,
    "fat" DOUBLE PRECISION NOT NULL,
    "fiber" DOUBLE PRECISION,
    "sugar" DOUBLE PRECISION,
    "sodium" DOUBLE PRECISION,
    "source" "FoodSource" NOT NULL DEFAULT 'USER',
    "isVerified" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "food_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "food_logs" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "dailyProgressId" TEXT,
    "foodItemId" TEXT NOT NULL,
    "mealType" "MealType" NOT NULL,
    "grams" DOUBLE PRECISION NOT NULL,
    "calories" DOUBLE PRECISION NOT NULL,
    "protein" DOUBLE PRECISION NOT NULL,
    "carbs" DOUBLE PRECISION NOT NULL,
    "fat" DOUBLE PRECISION NOT NULL,
    "fiber" DOUBLE PRECISION,
    "loggedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "food_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "qr_nonces" (
    "nonce" TEXT NOT NULL,
    "gymId" TEXT NOT NULL,
    "type" "QrType" NOT NULL,
    "usedAt" TIMESTAMP(3),
    "usedBy" TEXT,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "qr_nonces_pkey" PRIMARY KEY ("nonce")
);

-- CreateTable
CREATE TABLE "daily_recoveries" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "date" DATE NOT NULL,
    "hrv" DOUBLE PRECISION,
    "restingHR" INTEGER,
    "sleepHours" DOUBLE PRECISION,
    "sleepQuality" INTEGER,
    "recoveryScore" INTEGER NOT NULL DEFAULT 0,
    "source" "RecoverySource" NOT NULL DEFAULT 'MANUAL',
    "rawData" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "daily_recoveries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "gym_zones" (
    "id" TEXT NOT NULL,
    "gymId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "capacity" INTEGER NOT NULL DEFAULT 20,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "orderIndex" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "gym_zones_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "hardware_gateways_apiKey_key" ON "hardware_gateways"("apiKey");

-- CreateIndex
CREATE INDEX "gateway_commands_gatewayId_status_idx" ON "gateway_commands"("gatewayId", "status");

-- CreateIndex
CREATE INDEX "card_credentials_gymId_cardUid_idx" ON "card_credentials"("gymId", "cardUid");

-- CreateIndex
CREATE UNIQUE INDEX "card_credentials_gymId_cardUid_key" ON "card_credentials"("gymId", "cardUid");

-- CreateIndex
CREATE INDEX "deposits_gymId_status_idx" ON "deposits"("gymId", "status");

-- CreateIndex
CREATE INDEX "deposits_gymId_type_idx" ON "deposits"("gymId", "type");

-- CreateIndex
CREATE INDEX "marketing_campaigns_gymId_status_idx" ON "marketing_campaigns"("gymId", "status");

-- CreateIndex
CREATE INDEX "automation_rules_gymId_isActive_idx" ON "automation_rules"("gymId", "isActive");

-- CreateIndex
CREATE INDEX "gym_announcements_gymId_publishedAt_idx" ON "gym_announcements"("gymId", "publishedAt" DESC);

-- CreateIndex
CREATE INDEX "training_sessions_gymId_startTime_idx" ON "training_sessions"("gymId", "startTime");

-- CreateIndex
CREATE INDEX "training_sessions_trainerId_startTime_idx" ON "training_sessions"("trainerId", "startTime");

-- CreateIndex
CREATE INDEX "session_bookings_userId_status_idx" ON "session_bookings"("userId", "status");

-- CreateIndex
CREATE UNIQUE INDEX "session_bookings_sessionId_userId_key" ON "session_bookings"("sessionId", "userId");

-- CreateIndex
CREATE INDEX "support_tickets_gymId_status_idx" ON "support_tickets"("gymId", "status");

-- CreateIndex
CREATE INDEX "support_tickets_userId_idx" ON "support_tickets"("userId");

-- CreateIndex
CREATE INDEX "ticket_messages_ticketId_createdAt_idx" ON "ticket_messages"("ticketId", "createdAt");

-- CreateIndex
CREATE INDEX "audit_logs_gymId_createdAt_idx" ON "audit_logs"("gymId", "createdAt" DESC);

-- CreateIndex
CREATE INDEX "audit_logs_actorId_idx" ON "audit_logs"("actorId");

-- CreateIndex
CREATE INDEX "webhook_endpoints_gymId_idx" ON "webhook_endpoints"("gymId");

-- CreateIndex
CREATE INDEX "webhook_deliveries_endpointId_attemptedAt_idx" ON "webhook_deliveries"("endpointId", "attemptedAt" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "progress_rooms_inviteCode_key" ON "progress_rooms"("inviteCode");

-- CreateIndex
CREATE INDEX "progress_rooms_gymId_isActive_idx" ON "progress_rooms"("gymId", "isActive");

-- CreateIndex
CREATE INDEX "room_memberships_roomId_totalPoints_idx" ON "room_memberships"("roomId", "totalPoints" DESC);

-- CreateIndex
CREATE INDEX "room_memberships_userId_idx" ON "room_memberships"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "room_memberships_roomId_userId_key" ON "room_memberships"("roomId", "userId");

-- CreateIndex
CREATE INDEX "point_events_userId_roomId_idx" ON "point_events"("userId", "roomId");

-- CreateIndex
CREATE INDEX "point_events_roomId_createdAt_idx" ON "point_events"("roomId", "createdAt" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "exercise_library_name_key" ON "exercise_library"("name");

-- CreateIndex
CREATE INDEX "exercise_library_primaryMuscle_idx" ON "exercise_library"("primaryMuscle");

-- CreateIndex
CREATE INDEX "exercise_library_mechanics_idx" ON "exercise_library"("mechanics");

-- CreateIndex
CREATE UNIQUE INDEX "food_items_barcode_key" ON "food_items"("barcode");

-- CreateIndex
CREATE INDEX "food_items_name_idx" ON "food_items"("name");

-- CreateIndex
CREATE INDEX "food_items_barcode_idx" ON "food_items"("barcode");

-- CreateIndex
CREATE INDEX "food_items_source_isVerified_idx" ON "food_items"("source", "isVerified");

-- CreateIndex
CREATE INDEX "food_logs_userId_loggedAt_idx" ON "food_logs"("userId", "loggedAt" DESC);

-- CreateIndex
CREATE INDEX "food_logs_dailyProgressId_idx" ON "food_logs"("dailyProgressId");

-- CreateIndex
CREATE INDEX "qr_nonces_expiresAt_idx" ON "qr_nonces"("expiresAt");

-- CreateIndex
CREATE INDEX "qr_nonces_gymId_idx" ON "qr_nonces"("gymId");

-- CreateIndex
CREATE INDEX "daily_recoveries_userId_date_idx" ON "daily_recoveries"("userId", "date" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "daily_recoveries_userId_date_key" ON "daily_recoveries"("userId", "date");

-- CreateIndex
CREATE INDEX "gym_zones_gymId_isActive_idx" ON "gym_zones"("gymId", "isActive");

-- CreateIndex
CREATE UNIQUE INDEX "gym_zones_gymId_name_key" ON "gym_zones"("gymId", "name");

-- CreateIndex
CREATE INDEX "attendances_gymId_checkIn_idx" ON "attendances"("gymId", "checkIn" DESC);

-- CreateIndex
CREATE INDEX "attendances_userId_checkIn_idx" ON "attendances"("userId", "checkIn" DESC);

-- CreateIndex
CREATE INDEX "completed_sets_exerciseLibraryId_idx" ON "completed_sets"("exerciseLibraryId");

-- CreateIndex
CREATE INDEX "daily_progress_userId_date_idx" ON "daily_progress"("userId", "date" DESC);

-- CreateIndex
CREATE INDEX "exercise_sets_exerciseLibraryId_idx" ON "exercise_sets"("exerciseLibraryId");

-- CreateIndex
CREATE INDEX "gym_memberships_userId_gymId_status_idx" ON "gym_memberships"("userId", "gymId", "status");

-- CreateIndex
CREATE INDEX "gym_memberships_gymId_status_idx" ON "gym_memberships"("gymId", "status");

-- CreateIndex
CREATE UNIQUE INDEX "gyms_registrationCode_key" ON "gyms"("registrationCode");

-- CreateIndex
CREATE INDEX "workout_history_userId_completedAt_idx" ON "workout_history"("userId", "completedAt" DESC);

-- CreateIndex
CREATE INDEX "workout_history_routineId_idx" ON "workout_history"("routineId");

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_activeGymId_fkey" FOREIGN KEY ("activeGymId") REFERENCES "gyms"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "hardware_gateways" ADD CONSTRAINT "hardware_gateways_gymId_fkey" FOREIGN KEY ("gymId") REFERENCES "gyms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "gateway_commands" ADD CONSTRAINT "gateway_commands_gatewayId_fkey" FOREIGN KEY ("gatewayId") REFERENCES "hardware_gateways"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "card_credentials" ADD CONSTRAINT "card_credentials_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "card_credentials" ADD CONSTRAINT "card_credentials_gymId_fkey" FOREIGN KEY ("gymId") REFERENCES "gyms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "attendances" ADD CONSTRAINT "attendances_zoneId_fkey" FOREIGN KEY ("zoneId") REFERENCES "gym_zones"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "deposits" ADD CONSTRAINT "deposits_approvedById_fkey" FOREIGN KEY ("approvedById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "deposits" ADD CONSTRAINT "deposits_gymId_fkey" FOREIGN KEY ("gymId") REFERENCES "gyms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "deposits" ADD CONSTRAINT "deposits_submittedById_fkey" FOREIGN KEY ("submittedById") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "exercise_sets" ADD CONSTRAINT "exercise_sets_exerciseLibraryId_fkey" FOREIGN KEY ("exerciseLibraryId") REFERENCES "exercise_library"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "completed_sets" ADD CONSTRAINT "completed_sets_exerciseLibraryId_fkey" FOREIGN KEY ("exerciseLibraryId") REFERENCES "exercise_library"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "marketing_campaigns" ADD CONSTRAINT "marketing_campaigns_gymId_fkey" FOREIGN KEY ("gymId") REFERENCES "gyms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "marketing_campaigns" ADD CONSTRAINT "marketing_campaigns_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "automation_rules" ADD CONSTRAINT "automation_rules_gymId_fkey" FOREIGN KEY ("gymId") REFERENCES "gyms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "gym_announcements" ADD CONSTRAINT "gym_announcements_gymId_fkey" FOREIGN KEY ("gymId") REFERENCES "gyms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "gym_announcements" ADD CONSTRAINT "gym_announcements_authorId_fkey" FOREIGN KEY ("authorId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "training_sessions" ADD CONSTRAINT "training_sessions_gymId_fkey" FOREIGN KEY ("gymId") REFERENCES "gyms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "training_sessions" ADD CONSTRAINT "training_sessions_trainerId_fkey" FOREIGN KEY ("trainerId") REFERENCES "trainer_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "session_bookings" ADD CONSTRAINT "session_bookings_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "training_sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "session_bookings" ADD CONSTRAINT "session_bookings_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "support_tickets" ADD CONSTRAINT "support_tickets_gymId_fkey" FOREIGN KEY ("gymId") REFERENCES "gyms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "support_tickets" ADD CONSTRAINT "support_tickets_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ticket_messages" ADD CONSTRAINT "ticket_messages_ticketId_fkey" FOREIGN KEY ("ticketId") REFERENCES "support_tickets"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ticket_messages" ADD CONSTRAINT "ticket_messages_senderId_fkey" FOREIGN KEY ("senderId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_gymId_fkey" FOREIGN KEY ("gymId") REFERENCES "gyms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_actorId_fkey" FOREIGN KEY ("actorId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "webhook_endpoints" ADD CONSTRAINT "webhook_endpoints_gymId_fkey" FOREIGN KEY ("gymId") REFERENCES "gyms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "webhook_deliveries" ADD CONSTRAINT "webhook_deliveries_endpointId_fkey" FOREIGN KEY ("endpointId") REFERENCES "webhook_endpoints"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "progress_rooms" ADD CONSTRAINT "progress_rooms_gymId_fkey" FOREIGN KEY ("gymId") REFERENCES "gyms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "progress_rooms" ADD CONSTRAINT "progress_rooms_creatorId_fkey" FOREIGN KEY ("creatorId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_memberships" ADD CONSTRAINT "room_memberships_roomId_fkey" FOREIGN KEY ("roomId") REFERENCES "progress_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_memberships" ADD CONSTRAINT "room_memberships_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "point_events" ADD CONSTRAINT "point_events_membershipId_fkey" FOREIGN KEY ("membershipId") REFERENCES "room_memberships"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "food_logs" ADD CONSTRAINT "food_logs_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "food_logs" ADD CONSTRAINT "food_logs_foodItemId_fkey" FOREIGN KEY ("foodItemId") REFERENCES "food_items"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "food_logs" ADD CONSTRAINT "food_logs_dailyProgressId_fkey" FOREIGN KEY ("dailyProgressId") REFERENCES "daily_progress"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "daily_recoveries" ADD CONSTRAINT "daily_recoveries_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "gym_zones" ADD CONSTRAINT "gym_zones_gymId_fkey" FOREIGN KEY ("gymId") REFERENCES "gyms"("id") ON DELETE CASCADE ON UPDATE CASCADE;
