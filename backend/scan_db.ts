import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('--- COMPREHENSIVE DB SCAN ---');
  
  const users = await prisma.user.findMany({
    select: { id: true, email: true, role: true, fullName: true }
  });
  console.log('USERS IN DB:');
  users.forEach(u => console.log(`- ${u.id} | ${u.email} | ${u.role} | ${u.fullName}`));
  
  const gyms = await prisma.gym.findMany({
    select: { id: true, name: true, ownerId: true }
  });
  console.log('\nGYMS IN DB:');
  gyms.forEach(g => console.log(`- ${g.id} | ${g.name} | Owner: ${g.ownerId}`));
  
  const memberships = await prisma.gymMembership.count();
  console.log(`\nTotal Memberships: ${memberships}`);
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
