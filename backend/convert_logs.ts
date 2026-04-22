import * as fs from 'fs';

function convertToUtf8(filename: string, outname: string) {
  try {
    const buffer = fs.readFileSync(filename);
    // Try to detect utf16le
    const content = buffer.toString('utf16le');
    fs.writeFileSync(outname, content, 'utf8');
    console.log(`Converted ${filename} to ${outname}`);
  } catch (err: any) {
    console.error(`Error converting ${filename}:`, err.message);
  }
}

convertToUtf8('db_check.json', 'db_check_utf8.json');
convertToUtf8('backend_debug_3001.log', 'backend_debug_utf8.log');
