import { AuthService } from './src/modules/auth/auth.service';

async function test() {
  try {
    const result = await AuthService.login({
      email: 'mobile@amirani.dev',
      password: 'MobileUser123!'
    });
    console.log('Login success:', JSON.stringify(result, null, 2));
  } catch (err: any) {
    console.error('Login failed with error:');
    console.error(err);
    if (err.details) console.error('Details:', err.details);
    if (err.stack) console.error('Stack:', err.stack);
  }
}

test();
