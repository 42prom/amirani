import { PrismaClient, Role } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('[Check User] Listing users with role SUPER_ADMIN:');
  try {
    const admin = await prisma.user.findFirst({
      where: { role: Role.SUPER_ADMIN },
    });

    if (admin) {
      console.log(`[Check User] Found Admin: ${admin.email}`);
      console.log(`[Check User] Status: ${admin.isActive ? 'Active' : 'Inactive'}, Verified: ${admin.isVerified}`);
    } else {
      console.log('[Check User] No SUPER_ADMIN found in database.');
    }
  } catch (error) {
    console.error('[Check User] Error querying database:', error);
  } finally {
    await prisma.$disconnect();
  }
}

main();
