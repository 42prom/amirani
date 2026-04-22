import { PrismaClient, Role } from '@prisma/client';
const prisma = new PrismaClient();

async function main() {
  const email = `test_new_member_${Date.now()}@example.com`;
  console.log(`Attempting to create user: ${email}`);
  try {
    const user = await prisma.user.create({
      data: {
        email,
        fullName: 'Test New Member',
        password: '',
        role: Role.GYM_MEMBER,
        isVerified: true,
      },
    });
    console.log('User created successfully:', user.id);
    
    // Cleanup
    await prisma.user.delete({ where: { id: user.id } });
    console.log('Test user cleaned up.');
  } catch (err: any) {
    console.error('FAILED to create user.');
    console.error('Error Message:', err.message);
    console.error('Error Code:', err.code);
    console.error('Error Meta:', JSON.stringify(err.meta, null, 2));
  } finally {
    await prisma.$disconnect();
  }
}

main();
