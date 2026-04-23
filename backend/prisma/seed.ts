/// <reference types="node" />
import { PrismaClient, Role } from '@prisma/client';
import bcrypt from 'bcryptjs';
import { seedExerciseLibrary } from './exercise-seed';
import { seedAIConfig } from './ai-config-seed';
import { seedPlatformConfig } from './platform-config-seed';

const prisma = new PrismaClient();

/**
 * DEVELOPMENT SEED DATA
 *
 * This creates a minimal, locked set of test data for development:
 * - 1 Super Admin (platform administrator)
 * - 1 Gym Owner (owns 1 gym)
 * - 1 Branch Administrator (manages the gym)
 * - 1 Subscription Plan (for testing)
 * - 1 Door System (for testing access)
 *
 * Credentials:
 * - Super Admin: super@amirani.dev / SuperAdmin123!
 * - Gym Owner: owner@amirani.dev / GymOwner123!
 * - Branch Admin: branch@amirani.dev / BranchAdmin123!
 */

async function main() {
  console.log('🌱 Starting seed...');

  // Clear existing data (in reverse dependency order)
  console.log('🗑️  Clearing existing data...');
  await prisma.doorAccessLog.deleteMany();
  await prisma.attendance.deleteMany();
  await prisma.notification.deleteMany();
  await prisma.notificationPreference.deleteMany();
  await prisma.payment.deleteMany();
  await prisma.gymMembership.deleteMany();
  await prisma.trainerProfile.deleteMany();
  await prisma.doorSystem.deleteMany();
  await prisma.equipment.deleteMany();
  await prisma.subscriptionPlan.deleteMany();
  await prisma.gym.deleteMany();
  await prisma.invitation.deleteMany();
  await prisma.user.deleteMany();
  await (prisma as any).auditLog.deleteMany();
  await (prisma as any).userWeightHistory.deleteMany();
  await (prisma as any).branch.deleteMany();
  await (prisma as any).equipmentCatalog.deleteMany();

  // Hash passwords
  const superAdminPassword = await bcrypt.hash('SuperAdmin123!', 10);
  const gymOwnerPassword = await bcrypt.hash('GymOwner123!', 10);
  const branchAdminPassword = await bcrypt.hash('BranchAdmin123!', 10);
  const mobileUserPassword = await bcrypt.hash('MobileUser123!', 10);
  const trainerPassword = await bcrypt.hash('Trainer123!', 10);

  // 1. Create Super Admin
  console.log('👤 Creating Super Admin...');
  const superAdmin = await prisma.user.create({
    data: {
      email: 'super@amirani.dev',
      password: superAdminPassword,
      fullName: 'System Administrator',
      role: Role.SUPER_ADMIN,
      phoneNumber: '+1-555-0001',
      isVerified: true,
      isActive: true,
    },
  });
  console.log(`   ✓ Super Admin: ${superAdmin.email}`);

  // 2. Create Gym Owner
  console.log('👤 Creating Gym Owner...');
  const gymOwner = await prisma.user.create({
    data: {
      email: 'owner@amirani.dev',
      password: gymOwnerPassword,
      fullName: 'Demo Gym Owner',
      role: Role.GYM_OWNER,
      phoneNumber: '+1-555-0002',
      isVerified: true,
      isActive: true,
      createdById: superAdmin.id,
      saasSubscriptionStatus: 'TRIAL',
      saasTrialEndsAt: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000), // 14 days from now
    },
  });
  console.log(`   ✓ Gym Owner: ${gymOwner.email}`);

  // 3. Create Gym owned by Gym Owner
  console.log('🏋️ Creating Gym...');
  const gym = await prisma.gym.create({
    data: {
      name: 'Demo Fitness Center',
      address: '123 Development Street',
      city: 'Test City',
      country: 'Georgia',
      phone: '+995-555-123456',
      email: 'contact@demogym.dev',
      description: 'A demo gym for development and testing purposes.',
      isActive: true,
      ownerId: gymOwner.id,
    },
  });
  console.log(`   ✓ Gym: ${gym.name} (ID: ${gym.id})`);
  
  // 3b. Create Main Branch for Gym
  console.log('🏗️ Creating Main Branch...');
  const branch1 = await (prisma as any).branch.create({
    data: {
      name: 'Main Branch',
      address: gym.address,
      gymId: gym.id,
      isActive: true,
    },
  });
  console.log(`   ✓ Branch: ${branch1.name} (ID: ${branch1.id})`);

  // 4. Create Branch Administrator for the gym
  console.log('👤 Creating Branch Administrator...');
  const branchAdmin = await (prisma as any).user.create({
    data: {
      email: 'branch@amirani.dev',
      password: branchAdminPassword,
      fullName: 'Demo Branch Admin',
      role: Role.BRANCH_ADMIN,
      phoneNumber: '+1-555-0003',
      isVerified: true,
      isActive: true,
      createdById: gymOwner.id,
      managedGymId: gym.id, // Assign to manage this gym
      branchAdminOf: {
        connect: [{ id: branch1.id }]
      },
    },
  });
  console.log(`   ✓ Branch Admin: ${branchAdmin.email} (manages: ${gym.name})`);

  // 4b. Create Second Gym (Elite Fitness Center)
  console.log('🏋️ Creating Second Gym...');
  const gym2 = await prisma.gym.create({
    data: {
      name: 'Elite Fitness Center',
      address: '456 Premium Boulevard',
      city: 'Batumi',
      country: 'Georgia',
      phone: '+995-555-987654',
      email: 'contact@elitegym.dev',
      description: 'A premium branch for high-end fitness tracking.',
      isActive: true,
      ownerId: gymOwner.id,
    },
  });
  console.log(`   ✓ Gym: ${gym2.name} (ID: ${gym2.id})`);
  
  // 4b-1. Create Branch for Elite Fitness
  const branch2 = await (prisma as any).branch.create({
    data: {
      name: 'North Batumi Branch',
      address: gym2.address,
      gymId: gym2.id,
      isActive: true,
    },
  });
  console.log(`   ✓ Branch: ${branch2.name} (ID: ${branch2.id})`);

  // 4c. Create Mock Mobile User
  console.log('👤 Creating Mock Mobile User...');
  const mobileUser = await prisma.user.create({
    data: {
      email: 'mobile@amirani.dev',
      password: mobileUserPassword,
      fullName: 'Mobile Test User',
      role: Role.GYM_MEMBER,
      phoneNumber: '+1-555-9999',
      isVerified: true,
      isActive: true,
      createdById: superAdmin.id,
    },
  });
  console.log(`   ✓ Mobile User: ${mobileUser.email}`);
  
  // 4c-1. Create Weight History for Mobile User
  console.log('⚖️ Creating Weight History...');
  const weights = [85.5, 84.8, 84.2, 83.5];
  for (let i = 0; i < weights.length; i++) {
    const date = new Date();
    date.setDate(date.getDate() - (i * 7)); // Weekly history
    await (prisma as any).userWeightHistory.create({
      data: {
        userId: mobileUser.id,
        weight: weights[i],
        date,
      },
    });
  }
  console.log(`   ✓ ${weights.length} weight history records created`);

  // 5. Create a basic subscription plan for the gym
  console.log('📋 Creating Subscription Plan...');
  const plan = await prisma.subscriptionPlan.create({
    data: {
      name: 'Full Access',
      description: 'Unlimited gym access anytime',
      price: 50.00,
      durationValue: 30,
      durationUnit: 'days',
      features: [
        'Unlimited gym access',
        'All equipment access',
        'Locker room access',
        'Free parking',
      ],
      isActive: true,
      gymId: gym.id,
      hasTimeRestriction: false,
      planType: 'full',
      displayOrder: 1,
    },
  });
  console.log(`   ✓ Plan: ${plan.name} - $${plan.price}/month`);

  // 6. Create a door system for the gym
  console.log('🚪 Creating Door System...');
  const doorSystem = await prisma.doorSystem.create({
    data: {
      name: 'Main Entrance',
      type: 'QR_CODE',
      location: 'Front Door',
      isActive: true,
      gymId: gym.id,
      vendorConfig: {
        provider: 'mock',
        mockDelay: 500,
      },
    },
  });
  console.log(`   ✓ Door: ${doorSystem.name} (${doorSystem.type})`);

  // 7. Create Membership for Mobile User in Demo Fitness Center (managed by Branch Admin)
  console.log('💳 Creating Membership for Mobile User...');
  const membership = await prisma.gymMembership.create({
    data: {
      userId: mobileUser.id,
      gymId: gym.id, // Linked to the same gym as branchAdmin
      planId: plan.id,
      status: 'ACTIVE',
      startDate: new Date(),
      endDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days
    },
  });
  console.log(`   ✓ Membership active for ${mobileUser.email} in ${gym.name}`);

  // 8. Create Equipment for the Gym
  console.log('🦾 Creating Equipment...');
  const equipment = [
    { name: 'Dumbbell Set (1kg - 50kg)', category: 'FREE_WEIGHTS', quantity: 1, brand: 'IronGrip', status: 'AVAILABLE' },
    { name: 'Olympic Barbell', category: 'FREE_WEIGHTS', quantity: 4, brand: 'Rogue', status: 'AVAILABLE' },
    { name: 'Adjustable Bench', category: 'STRENGTH', quantity: 6, brand: 'Matrix', status: 'AVAILABLE' },
    { name: 'Leg Press Machine', category: 'MACHINES', quantity: 2, brand: 'LifeFitness', status: 'AVAILABLE' },
    { name: 'Treadmill Pro X1', category: 'CARDIO', quantity: 10, brand: 'Technogym', status: 'AVAILABLE' },
    { name: 'Elliptical Trainer', category: 'CARDIO', quantity: 5, brand: 'Technogym', status: 'AVAILABLE' },
    { name: 'Kettlebell Set', category: 'FREE_WEIGHTS', quantity: 1, brand: 'Eleiko', status: 'AVAILABLE' },
    { name: 'Pull-up Station', category: 'STRENGTH', quantity: 3, brand: 'Rogue', status: 'AVAILABLE' },
    { name: 'Resistance Bands', category: 'FUNCTIONAL', quantity: 20, brand: 'TheraBand', status: 'AVAILABLE' },
    { name: 'Yoga Mats & Blocks', category: 'STRETCHING', quantity: 15, brand: 'Lululemon', status: 'AVAILABLE' },
    { name: 'Rowing Machine', category: 'CARDIO', quantity: 4, brand: 'Concept2', status: 'AVAILABLE' },
    { name: 'Squat Rack', category: 'STRENGTH', quantity: 4, brand: 'Rogue', status: 'AVAILABLE' },
  ];

  for (const item of equipment) {
    await prisma.equipment.create({
      data: {
        ...item,
        gymId: gym.id,
        category: item.category as any,
        status: item.status as any,
      },
    });
  }
  console.log(`   ✓ ${equipment.length} equipment items created`);

  // 9. Create Trainers for the Gym
  console.log('🧑‍🏫 Creating Trainers...');

  // 9a. Create a loginable Trainer user linked to a TrainerProfile (for web admin)
  console.log('👤 Creating Trainer User (web login)...');
  const trainerUser = await prisma.user.create({
    data: {
      email: 'trainer@amirani.dev',
      password: trainerPassword,
      fullName: 'Alex Rivera',
      role: Role.TRAINER,
      phoneNumber: '+1-555-0004',
      isVerified: true,
      isActive: true,
      createdById: branchAdmin.id,
    },
  });
  console.log(`   ✓ Trainer User: ${trainerUser.email}`);

  // Create the linked TrainerProfile for the loginable trainer
  const trainerProfile = await prisma.trainerProfile.create({
    data: {
      fullName: 'Alex Rivera',
      specialization: 'Strength & Conditioning',
      bio: 'Expert in powerlifting and athletic performance with 10+ years experience.',
      avatarUrl: 'https://ui-avatars.com/api/?name=Alex+Rivera&background=1A2035&color=F1C40F&size=200',
      gymId: gym.id,
      isAvailable: true,
      userId: trainerUser.id,
    },
  });

  // Assign the mobile test member to this trainer
  await prisma.gymMembership.update({
    where: { id: membership.id },
    data: { trainerId: trainerProfile.id },
  });
  console.log(`   ✓ Mobile member assigned to trainer: ${trainerUser.fullName}`);

  // Remaining mock trainers (no login account — display only)
  const mockTrainers = [
    {
      fullName: 'Sarah Chen',
      specialization: 'Yoga & Flexibility',
      bio: 'Helping members find balance through mindful movement and advanced mobility.',
      avatarUrl: 'https://ui-avatars.com/api/?name=Sarah+Chen&background=1A2035&color=F1C40F&size=200',
    },
    {
      fullName: 'Marcus Thorne',
      specialization: 'Bodybuilding & Nutrition',
      bio: 'Specialist in hypertrophy and contest prep. Transform your physique today.',
      avatarUrl: 'https://ui-avatars.com/api/?name=Marcus+Thorne&background=1A2035&color=F1C40F&size=200',
    },
    {
      fullName: 'Elena Vance',
      specialization: 'HIIT & Weight Loss',
      bio: 'High energy coach focused on burning fat and building cardiovascular endurance.',
      avatarUrl: 'https://ui-avatars.com/api/?name=Elena+Vance&background=1A2035&color=F1C40F&size=200',
    },
  ];

  for (const trainer of mockTrainers) {
    await prisma.trainerProfile.create({
      data: { ...trainer, gymId: gym.id, isAvailable: true },
    });
  }
  console.log(`   ✓ ${mockTrainers.length + 1} trainer profiles created (1 with web login)`);

  // 10. Seed Exercise Library
  await seedExerciseLibrary();

  // 11. Seed AI Config (reads DEEPSEEK_API_KEY from .env — now creates placeholder if missing)
  await seedAIConfig();

  // 12. Seed Platform Config
  await seedPlatformConfig();

  // 13. Seed Badge Definitions
  console.log('🏅 Seeding badge definitions...');
  const badgeDefs = [
    { key: 'first_checkin',  name: 'First Steps',        description: 'Check into a gym for the first time',           tier: 'BRONZE',   sortOrder: 1  },
    { key: 'streak_3',       name: 'On a Roll',           description: 'Maintain a 3-day activity streak',              tier: 'BRONZE',   sortOrder: 2  },
    { key: 'streak_7',       name: 'Week Warrior',        description: 'Maintain a 7-day activity streak',              tier: 'SILVER',   sortOrder: 3  },
    { key: 'streak_30',      name: 'Iron Consistency',    description: 'Maintain a 30-day activity streak',             tier: 'GOLD',     sortOrder: 4  },
    { key: 'workout_5',      name: 'Getting Started',     description: 'Complete 5 workout sessions',                   tier: 'BRONZE',   sortOrder: 5  },
    { key: 'workout_25',     name: 'Dedicated',           description: 'Complete 25 workout sessions',                  tier: 'SILVER',   sortOrder: 6  },
    { key: 'workout_100',    name: 'Century Club',        description: 'Complete 100 workout sessions',                 tier: 'GOLD',     sortOrder: 7  },
    { key: 'points_100',     name: 'Point Scorer',        description: 'Earn 100 total leaderboard points',             tier: 'BRONZE',   sortOrder: 8  },
    { key: 'points_500',     name: 'High Achiever',       description: 'Earn 500 total leaderboard points',             tier: 'SILVER',   sortOrder: 9  },
    { key: 'points_2000',    name: 'Champion',            description: 'Earn 2,000 total leaderboard points',           tier: 'GOLD',     sortOrder: 10 },
    { key: 'perfect_day',    name: 'Perfect Day',         description: 'Complete 100% of your daily tasks',             tier: 'BRONZE',   sortOrder: 11 },
    { key: 'perfect_week',   name: 'Perfect Week',        description: 'Seven consecutive days of full task completion', tier: 'PLATINUM', sortOrder: 12 },
  ] as const;

  for (const def of badgeDefs) {
    await (prisma as any).badgeDefinition.upsert({
      where: { key: def.key },
      update: { name: def.name, description: def.description, tier: def.tier, sortOrder: def.sortOrder },
      create: { ...def, isActive: true },
    });
  }
  console.log(`   ✓ ${badgeDefs.length} badge definitions seeded`);

  // Summary
  console.log('\n═══════════════════════════════════════════════════════════');
  console.log('✅ SEED COMPLETED SUCCESSFULLY');
  console.log('═══════════════════════════════════════════════════════════');
  console.log('\n📌 Development Accounts:');
  console.log('┌─────────────────┬──────────────────────┬──────────────────┐');
  console.log('│ Role            │ Email                │ Password         │');
  console.log('├─────────────────┼──────────────────────┼──────────────────┤');
  console.log('│ SUPER_ADMIN     │ super@amirani.dev    │ SuperAdmin123!   │');
  console.log('│ GYM_OWNER       │ owner@amirani.dev    │ GymOwner123!     │');
  console.log('│ BRANCH_ADMIN    │ branch@amirani.dev   │ BranchAdmin123!  │');
  console.log('│ TRAINER         │ trainer@amirani.dev  │ Trainer123!      │');
  console.log('│ GYM_MEMBER      │ mobile@amirani.dev   │ MobileUser123!   │');
  console.log('└─────────────────┴──────────────────────┴──────────────────┘');
  console.log('\n🏋️ Gym Created:');
  console.log(`   Name: ${gym.name}`);
  console.log(`   ID: ${gym.id}`);
  console.log(`   Owner: ${gymOwner.fullName}`);
  console.log(`   Branch Admin: ${branchAdmin.fullName}`);
  console.log('═══════════════════════════════════════════════════════════\n');
}

main()
  .catch((e) => {
    console.error('❌ Seed failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
