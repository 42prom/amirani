import axios from 'axios';

const API_BASE_URL = 'http://localhost:3085/api';

async function runTests() {
  console.log('--- Starting Mobile API Integration Tests ---');
  let token = '';

  try {
    // 1. Login
    console.log('\n[1] Testing Login...');
    const loginRes = await axios.post(`${API_BASE_URL}/auth/login`, {
      email: 'mobile@amirani.dev',
      password: 'MobileUser123!'
    });
    
    token = loginRes.data.data.token;
    console.log(`✅ Login Successful. User: ${loginRes.data.data.user.email}`);
    
    axios.defaults.headers.common['Authorization'] = `Bearer ${token}`;

    // 2. Fetch Active Workout Plan
    console.log('\n[2] Testing Fetch Active Workout Plan...');
    try {
      const planRes = await axios.get(`${API_BASE_URL}/sync/workout/plan`);
      console.log(`✅ Fetch Plan Successful. Target Muscle: ${planRes.data.data.targetMuscleGroup}`);
    } catch (e: any) {
        if(e.response && e.response.status === 404) {
            console.log(`✅ Fetch Plan Handled 404 Correctly (No plan exists)`);
        } else {
            throw e;
        }
    }

    // 3. Generate Workout Plan (AI)
    console.log('\n[3] Testing Generate AI Workout Plan...');
    const generateRes = await axios.post(`${API_BASE_URL}/sync/ai/generate-plan`, {
      type: 'WORKOUT',
      goals: 'Build Muscle',
      fitnessLevel: 'INTERMEDIATE'
    });
    console.log(`✅ Generate Plan Successful. Message: ${generateRes.data.message}`);

    // 4. Fetch Daily Macros
    console.log('\n[4] Testing Fetch Daily Macros...');
    const macroRes = await axios.get(`${API_BASE_URL}/sync/diet/macros?date=${new Date().toISOString()}`);
    console.log(`✅ Fetch Macros Successful. Calories Target: ${macroRes.data.data.targetCalories}`);

    // 5. Gym NFC Check-In
    console.log('\n[5] Testing Gym NFC Check-In...');
    const { PrismaClient } = require('@prisma/client');
    const prisma = new PrismaClient();
    const membership = await prisma.gymMembership.findFirst({
      where: { user: { email: 'mobile@amirani.dev' } }
    });
    const gymIdToTest = membership?.gymId;
    await prisma.$disconnect();
    
    if (!gymIdToTest) {
      console.log('❌ Gym check-in skipped: No gyms found in the DB.');
    } else {
      // Revert to Mobile user
      axios.defaults.headers.common['Authorization'] = `Bearer ${token}`;
      const nfcRes = await axios.post(`${API_BASE_URL}/attendance/check-in`, {
          gymId: gymIdToTest,
          nfcPayload: 'test_payload_nfc_auth_buffer'
      });
      console.log(`✅ Gym Check-In Successful. Action: ${nfcRes.data.data.action}`);
    }

    console.log('\n🎉 All Core API Integration Tests Passed! 🎉');

  } catch (error: any) {
    console.error('\n❌ Test Failed! Wrote details to test_error.json');
    const fs = require('fs');
    if (error.response) {
      fs.writeFileSync('test_error.json', JSON.stringify({
        url: error.config.url,
        status: error.response.status,
        data: error.response.data
      }, null, 2));
    } else {
      fs.writeFileSync('test_error.json', JSON.stringify({ message: error.message }));
    }
  }
}

runTests();
