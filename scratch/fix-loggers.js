const fs = require('fs');
const path = require('path');

function walk(dir, callback) {
  fs.readdirSync(dir).forEach( f => {
    let dirPath = path.join(dir, f);
    let isDirectory = fs.statSync(dirPath).isDirectory();
    isDirectory ? walk(dirPath, callback) : callback(path.join(dir, f));
  });
};

const targetDir = path.join(__dirname, '../backend/src');

walk(targetDir, (filePath) => {
  if (filePath.endsWith('.ts')) {
    let content = fs.readFileSync(filePath, 'utf8');
    
    // Pattern: logger.error({ obj }, 'msg') -> logger.error('msg', { obj })
    // Handles single and double quotes
    const regex = /logger\.(error|info|warn|debug)\(\{\s*([\s\S]*?)\s*\}\s*,\s*(['"])([\s\S]*?)\3\)/g;
    
    let newContent = content.replace(regex, (match, level, obj, quote, msg) => {
      // Reorder to logger.level(msg, { obj })
      return `logger.${level}(${quote}${msg}${quote}, { ${obj} })`;
    });

    if (content !== newContent) {
      console.log(`Fixed: ${filePath}`);
      fs.writeFileSync(filePath, newContent, 'utf8');
    }
  }
});
