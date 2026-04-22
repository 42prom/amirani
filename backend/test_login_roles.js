const http = require('http');
const fs = require('fs');

const users = [
  { email: 'super@amirani.dev', password: 'SuperAdmin123!' },
  { email: 'owner@amirani.dev', password: 'GymOwner123!' },
  { email: 'branch@amirani.dev', password: 'BranchAdmin123!' },
  { email: 'mobile@amirani.dev', password: 'MobileUser123!' }
];

fs.writeFileSync('roles_out.txt', '');

function testLogin(user) {
  return new Promise((resolve) => {
    const data = JSON.stringify(user);
    const req = http.request({
      hostname: 'localhost',
      port: 3001,
      path: '/api/auth/login',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data)
      }
    }, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        fs.appendFileSync('roles_out.txt', `[${user.email}] Status: ${res.statusCode} | Response: ${body.substring(0, 100)}\n`);
        resolve();
      });
    });
    
    req.on('error', e => {
      fs.appendFileSync('roles_out.txt', `[${user.email}] Error: ${e.message}\n`);
      resolve();
    });
    req.write(data);
    req.end();
  });
}

async function run() {
  for (const u of users) {
    await testLogin(u);
  }
}

run();
