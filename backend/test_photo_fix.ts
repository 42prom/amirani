import { MembershipService } from './src/modules/memberships/membership.service';
import { Role } from '@prisma/client';
import prisma from './src/lib/prisma';

async function test() {
  const gymId = 'test-gym-id'; // Make sure this exists or use a real one
  const adminId = 'test-admin-id'; // Make sure this exists or use a real one
  
  // Find a real gym and admin if possible
  const gym = await prisma.gym.findFirst();
  const admin = await prisma.user.findFirst({ where: { role: 'SUPER_ADMIN' } });
  
  if (!gym || !admin) {
    console.error('Need at least one gym and one super admin in DB to test');
    process.exit(1);
  }

  const testEmail = `test-member-${Date.now()}@example.com`;
  const selfieUrl = 'https://example.com/selfie.jpg';
  const idPhotoUrl = 'https://example.com/id.jpg';

  const plan = await prisma.subscriptionPlan.findFirst({ where: { gymId: gym.id } });
  if (!plan) {
    console.error('Gym needs at least one subscription plan');
    process.exit(1);
  }

  console.log(`Registering ${testEmail}...`);
  const result = await MembershipService.manualCreateMember(
    gym.id,
    admin.id,
    Role.SUPER_ADMIN,
    {
      fullName: 'Test Photo Member',
      email: testEmail,
      subscriptionPlanId: plan.id,
      selfiePhoto: selfieUrl,
      idPhoto: idPhotoUrl,
    }
  );

  console.log('Result:', JSON.stringify(result, null, 2));

  if (result.user.avatarUrl === selfieUrl) {
    console.log('SUCCESS: avatarUrl (selfiePhoto) correctly saved and returned!');
  } else {
    console.error('FAILURE: avatarUrl mismatch!', result.user.avatarUrl);
  }

  // Verify in DB directly
  const dbUser = await prisma.user.findUnique({ where: { id: result.user.id } });
  if (dbUser?.idPhotoUrl === idPhotoUrl) {
    console.log('SUCCESS: idPhotoUrl correctly saved in DB!');
  } else {
    console.error('FAILURE: idPhotoUrl mismatch in DB!', dbUser?.idPhotoUrl);
  }

  await prisma.$disconnect();
}

test().catch(console.error);
