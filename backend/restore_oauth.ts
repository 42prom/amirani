import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

async function main() {
  const id = 'singleton';
  console.log('--- OAuth Configuration Recovery ---');
  
  try {
    const existing = await (prisma as any).oAuthConfig.findUnique({ where: { id } });
    
    if (existing) {
      console.log('Found existing OAuth configuration.');
      console.log('Current Google Client ID:', existing.googleClientId || 'NOT SET');
      console.log('Google Enabled:', existing.googleEnabled);
    } else {
      console.log('No OAuth configuration found. Creating singleton record...');
      await (prisma as any).oAuthConfig.create({
        data: {
          id,
          googleEnabled: true,
          googleClientId: '', // User needs to set this in Admin Dashboard
          appleEnabled: false,
        }
      });
      console.log('Singleton OAuthConfig record created successfully.');
    }
    
    console.log('\nNEXT STEPS:');
    console.log('1. Go to the Admin Dashboard -> OAuth Configuration.');
    console.log('2. Enter a valid Google Web Client ID (xxxxxx.apps.googleusercontent.com).');
    console.log('3. Ensure "Enabled" is toggled on.');
    console.log('4. Save the configuration.');
    
  } catch (err: any) {
    console.error('Error during recovery:', err.message);
  } finally {
    await prisma.$disconnect();
  }
}

main();
