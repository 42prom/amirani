import prisma from './src/lib/prisma';
import { recalculateUserStats } from './src/lib/leaderboard.service';

async function test() {
  const user = await prisma.user.findFirst();
  if (!user) {
    console.log('No user found');
    return;
  }
  console.log(`Recalculating for user: ${user.fullName} (${user.id})`);
  try {
    const res = await recalculateUserStats(user.id);
    console.log('Result:', res);
  } catch (err) {
    console.error('Failed:', err);
  } finally {
    await prisma.$disconnect();
  }
}

test();
