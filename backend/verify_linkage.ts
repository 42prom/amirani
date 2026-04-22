import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('🔍 Verifying seed data linkage...');

  // 1. Get the branch managed by the mock admin
  const branchAdmin = await prisma.user.findFirst({
    where: { email: 'branch@amirani.dev' },
    select: { id: true, fullName: true, managedGymId: true }
  });

  if (!branchAdmin || !branchAdmin.managedGymId) {
    console.error('❌ Mock Branch Admin not found or has no managed gym.');
    return;
  }

  const gym = await prisma.gym.findUnique({
    where: { id: branchAdmin.managedGymId },
    select: { id: true, name: true }
  });

  console.log(`✅ Branch Admin "${branchAdmin.fullName}" manages gym "${gym?.name}" (ID: ${gym?.id})`);

  // 2. Get the mock member and their memberships
  const mockMember = await prisma.user.findFirst({
    where: { email: 'mobile@amirani.dev' },
    include: {
      memberships: {
        include: {
          gym: true
        }
      }
    }
  });

  if (!mockMember) {
    console.error('❌ Mock Member (mobile@amirani.dev) not found.');
    return;
  }

  console.log(`👤 Mock Member: ${mockMember.fullName} (${mockMember.email})`);
  
  if (mockMember.memberships.length === 0) {
    console.error('❌ Mock Member has no active memberships.');
  } else {
    mockMember.memberships.forEach(m => {
      const isCorrectLink = m.gymId === gym?.id;
      console.log(`${isCorrectLink ? '✅' : '❌'} Enrolled in gym: ${m.gym.name} (ID: ${m.gymId})`);
    });
  }

  const allLinked = mockMember.memberships.some(m => m.gymId === gym?.id);
  if (allLinked) {
    console.log('\n✨ VERIFICATION SUCCESS: Mock Member is linked to Mock Admin\'s Branch! ✨');
  } else {
    console.error('\n❌ VERIFICATION FAILED: Mock Member is NOT linked to Mock Admin\'s Branch.');
  }
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
