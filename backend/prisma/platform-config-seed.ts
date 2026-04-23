import { PrismaClient, LanguagePreference } from '@prisma/client';

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

if (require.main === module) {
  seedPlatformConfig()
    .catch(console.error)
    .finally(() => prisma.$disconnect());
}
