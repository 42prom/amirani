const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  console.log('Searching for "dxdfds" in EquipmentCatalog...');
  const items = await prisma.equipmentCatalog.findMany({
    where: {
      OR: [
        { name: { contains: 'dxdfds', mode: 'insensitive' } },
        { brand: { contains: 'dxdfds', mode: 'insensitive' } },
        { model: { contains: 'dxdfds', mode: 'insensitive' } },
        { description: { contains: 'dxdfds', mode: 'insensitive' } },
      ]
    }
  });
  console.log('Found items:', JSON.stringify(items, null, 2));
  
  if (items.length === 0) {
    console.log('No "dxdfds" found. Listing all items:');
    const all = await prisma.equipmentCatalog.findMany({ take: 10 });
    console.log('All items (first 10):', JSON.stringify(all, null, 2));
  }
}

main()
  .catch(e => console.error(e))
  .finally(async () => await prisma.$disconnect());
