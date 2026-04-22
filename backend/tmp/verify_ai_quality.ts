import { buildWorkoutSystemPrompt, buildDietSystemPrompt, buildUserPrompt } from '../src/lib/queue';

const mockPayload = {
  userId: 'test-user-123',
  type: 'WORKOUT' as 'WORKOUT',
  goals: 'Hypertrophy focused on upper body strength',
  fitnessLevel: 'INTERMEDIATE' as 'INTERMEDIATE',
  daysPerWeek: 3,
  preferred_days: [1, 3, 5], // Mon, Wed, Fri
  target_muscles: ['pectorals', 'biceps', 'deltoids'],
  availableEquipment: ['barbell', 'dumbbell', 'cables'],
  userMetrics: {
    weightKg: 85,
    heightCm: 182,
    age: 28,
    gender: 'male',
    injuries: ['Right Knee Pain - Meniscus'],
  },
  dietaryStyle: 'Keto',
  allergies: ['Peanuts'],
  budgetPerDayUsd: 25,
  mealsPerDay: 4,
};

console.log('--- 🏋️ WORKOUT SYSTEM PROMPT ---');
console.log(buildWorkoutSystemPrompt());

console.log('\n--- 🏋️ WORKOUT USER PROMPT ---');
console.log(buildUserPrompt(mockPayload, 'WORKOUT'));

console.log('\n--- 🥗 DIET SYSTEM PROMPT ---');
console.log(buildDietSystemPrompt());

console.log('\n--- 🥗 DIET USER PROMPT ---');
console.log(buildUserPrompt(mockPayload, 'DIET'));
