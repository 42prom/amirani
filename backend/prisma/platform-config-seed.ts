import { PrismaClient, LanguagePreference } from '@prisma/client';

declare const process: any;

const prisma = new PrismaClient();

export async function seedPlatformConfig() {
  console.log('🌐 Seeding PlatformConfig...');

  const config = await prisma.platformConfig.upsert({
    where: { id: 'singleton' },
    create: {
      id: 'singleton',
      maintenanceMode: false,
      platformName: 'Amirani',
      supportEmail: 'support@amirani.esme.ge',
      termsOfServiceUrl: 'https://amirani.esme.ge/terms',
      privacyPolicyUrl: 'https://amirani.esme.ge/privacy',
    },
    update: {
      maintenanceMode: false,
    },
  });

  console.log(`   ✓ PlatformConfig active: platformName=${config.platformName}`);
  return config;
}

// Run the seed function directly
seedPlatformConfig()
  .then(() => {
    console.log('✅ Platform Config Seeding Complete');
  })
  .catch((e) => {
    console.error('❌ Platform Config Seeding Failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
