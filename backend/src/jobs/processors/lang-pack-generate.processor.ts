import { Job } from 'bullmq';
import Anthropic from '@anthropic-ai/sdk';
import axios from 'axios';
import prisma from '../../lib/prisma';
import logger from '../../lib/logger';
import { getAiConfig } from '../../lib/ai-config';

export interface LangPackGeneratePayload {
  language: string;        // uppercase e.g. "KA"
  targetLanguage: string;  // display name e.g. "Georgian"
  countryCode: string;     // lowercase e.g. "ge"
  requestedBy: string;     // super admin userId
}

// Mirrors EN_STRINGS in language-packs.controller.ts
const EN_STRINGS: Record<string, string> = {
  'button.save': 'Save', 'button.cancel': 'Cancel', 'button.confirm': 'Confirm',
  'button.delete': 'Delete', 'button.edit': 'Edit', 'button.back': 'Back',
  'button.next': 'Next', 'button.done': 'Done', 'button.retry': 'Retry',
  'button.close': 'Close', 'button.submit': 'Submit', 'button.continue': 'Continue',
  'button.skip': 'Skip', 'button.add': 'Add', 'button.remove': 'Remove',
  'button.update': 'Update', 'button.apply': 'Apply', 'button.generate': 'Generate',
  'button.refresh': 'Refresh',
  'auth.login': 'Login', 'auth.logout': 'Logout', 'auth.email': 'Email',
  'auth.password': 'Password', 'auth.confirm_password': 'Confirm Password',
  'auth.forgot_password': 'Forgot Password?', 'auth.reset_password': 'Reset Password',
  'auth.change_password': 'Change Password', 'auth.new_password': 'New Password',
  'auth.old_password': 'Current Password', 'auth.sign_in_google': 'Continue with Google',
  'auth.sign_in_apple': 'Continue with Apple', 'auth.no_account': "Don't have an account?",
  'auth.has_account': 'Already have an account?', 'auth.register': 'Register',
  'auth.welcome_back': 'Welcome Back', 'auth.enter_email': 'Enter your email',
  'auth.enter_password': 'Enter your password', 'auth.password_changed': 'Password changed successfully',
  'nav.home': 'Home', 'nav.workout': 'Workout', 'nav.diet': 'Diet', 'nav.gym': 'Gym',
  'nav.dashboard': 'Dashboard', 'nav.challenge': 'Challenge', 'nav.progress': 'Progress',
  'nav.profile': 'Profile', 'nav.settings': 'Settings',
  'dashboard.title': 'Dashboard', 'dashboard.good_morning': 'Good Morning',
  'dashboard.good_afternoon': 'Good Afternoon', 'dashboard.good_evening': 'Good Evening',
  'dashboard.weekly_summary': 'Weekly Summary', 'dashboard.todays_goal': "Today's Goal",
  'dashboard.streak': 'Streak', 'dashboard.calories': 'Calories', 'dashboard.steps': 'Steps',
  'dashboard.water': 'Water', 'dashboard.sleep': 'Sleep', 'dashboard.recovery': 'Recovery',
  'dashboard.readiness': 'Readiness', 'dashboard.no_data': 'No data yet',
  'workout.title': 'Workout', 'workout.start': 'Start Workout', 'workout.pause': 'Pause',
  'workout.resume': 'Resume', 'workout.finish': 'Finish Workout', 'workout.sets': 'Sets',
  'workout.reps': 'Reps', 'workout.weight': 'Weight', 'workout.rest': 'Rest',
  'workout.duration': 'Duration', 'workout.active_session': 'Active Session',
  'workout.no_plan': 'No workout plan assigned', 'workout.complete': 'Complete',
  'diet.title': 'Diet', 'diet.generate_plan': 'Generate Diet Plan', 'diet.calories': 'Calories',
  'diet.protein': 'Protein', 'diet.carbs': 'Carbs', 'diet.fat': 'Fat',
  'diet.breakfast': 'Breakfast', 'diet.lunch': 'Lunch', 'diet.dinner': 'Dinner',
  'diet.snack': 'Snack', 'diet.water_intake': 'Water Intake', 'diet.no_plan': 'No diet plan assigned',
  'diet.daily_target': 'Daily Target',
  'gym.title': 'Gym', 'gym.join': 'Join Gym', 'gym.leave': 'Leave Gym',
  'gym.members': 'Members', 'gym.trainer': 'Trainer', 'gym.schedule': 'Schedule',
  'gym.membership': 'Membership', 'gym.active': 'Active', 'gym.expired': 'Expired',
  'gym.pending': 'Pending Approval', 'gym.no_gym': 'Not a member of any gym',
  'gym.scan_qr': 'Scan QR Code', 'gym.register': 'Register with Gym',
  'settings.title': 'Settings', 'settings.language': 'Language',
  'settings.downloading_language': 'Downloading language...',
  'settings.language_unavailable': 'Language unavailable offline. Connect to download.',
  'settings.profile': 'Profile', 'settings.notifications': 'Notifications',
  'settings.privacy': 'Privacy', 'settings.about': 'About', 'settings.version': 'Version',
  'settings.logout': 'Logout', 'settings.delete_account': 'Delete Account',
  'profile.title': 'Profile', 'profile.first_name': 'First Name', 'profile.last_name': 'Last Name',
  'profile.phone': 'Phone Number', 'profile.dob': 'Date of Birth', 'profile.gender': 'Gender',
  'profile.weight': 'Weight (kg)', 'profile.height': 'Height (cm)',
  'profile.edit_photo': 'Edit Photo', 'profile.save_changes': 'Save Changes',
  'error.generic': 'Something went wrong. Please try again.',
  'error.network': 'No internet connection.',
  'error.session_expired': 'Session expired. Please log in again.',
  'error.invalid_credentials': 'Invalid email or password.',
  'error.required_field': 'This field is required.',
  'error.invalid_email': 'Please enter a valid email.',
  'error.password_too_short': 'Password must be at least 8 characters.',
  'error.passwords_no_match': 'Passwords do not match.',
  'error.server': 'Server error. Please try again later.',
  'label.loading': 'Loading...', 'label.no_results': 'No results found.',
  'label.today': 'Today', 'label.yesterday': 'Yesterday', 'label.this_week': 'This Week',
  'label.optional': 'Optional', 'label.required': 'Required', 'label.or': 'or',
  'label.search': 'Search', 'label.filter': 'Filter', 'label.sort': 'Sort',
  'label.all': 'All', 'label.active': 'Active', 'label.inactive': 'Inactive',
  'onboarding.get_started': 'Get Started', 'onboarding.welcome': 'Welcome to Amirani',
  'onboarding.subtitle': 'Your Personal Fitness Platform',
};

async function callAi(targetLanguage: string): Promise<string> {
  const systemPrompt = `Translate these English mobile app UI strings into ${targetLanguage}. Rules: keep translations SHORT and UI-friendly (buttons/labels/menus), do not add notes, return ONLY a valid JSON object with the same keys.`;
  const userPrompt = JSON.stringify(EN_STRINGS);

  const aiConfig = await getAiConfig();

  if (!aiConfig) {
    if (!process.env.ANTHROPIC_API_KEY) throw new Error('No AI provider configured');
    const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
    const res = await client.messages.create({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 8192,
      messages: [{ role: 'user', content: `${systemPrompt}\n\n${userPrompt}` }],
    });
    return res.content[0].type === 'text' ? res.content[0].text : '';
  }

  if (aiConfig.activeProvider === 'OPENAI' && aiConfig.openaiApiKey) {
    const r = await axios.post('https://api.openai.com/v1/chat/completions', {
      model: aiConfig.openaiModel || 'gpt-4o',
      messages: [{ role: 'system', content: systemPrompt }, { role: 'user', content: userPrompt }],
      response_format: { type: 'json_object' },
    }, { headers: { Authorization: `Bearer ${aiConfig.openaiApiKey}` } });
    return r.data.choices[0].message.content;
  }

  if (aiConfig.activeProvider === 'ANTHROPIC' && aiConfig.anthropicApiKey) {
    const client = new Anthropic({ apiKey: aiConfig.anthropicApiKey });
    const res = await client.messages.create({
      model: aiConfig.anthropicModel || 'claude-haiku-4-5-20251001',
      max_tokens: 8192,
      system: systemPrompt,
      messages: [{ role: 'user', content: userPrompt }],
    });
    return res.content[0].type === 'text' ? res.content[0].text : '';
  }

  if (aiConfig.activeProvider === 'DEEPSEEK' && aiConfig.deepseekApiKey) {
    const r = await axios.post(`${aiConfig.deepseekBaseUrl}/chat/completions`, {
      model: aiConfig.deepseekModel || 'deepseek-chat',
      messages: [{ role: 'system', content: systemPrompt }, { role: 'user', content: userPrompt }],
      response_format: { type: 'json_object' },
    }, { headers: { Authorization: `Bearer ${aiConfig.deepseekApiKey}` } });
    return r.data.choices[0].message.content;
  }

  throw new Error(`AI provider '${aiConfig.activeProvider}' has no valid API key`);
}

export async function processLangPackGenerate(job: Job<LangPackGeneratePayload>): Promise<void> {
  const { language, targetLanguage, countryCode } = job.data;
  logger.info('[LangPackWorker] Starting', { language, targetLanguage });

  const rawText = await callAi(targetLanguage);

  const jsonMatch = rawText.match(/\{[\s\S]*\}/);
  if (!jsonMatch) throw new Error('AI returned unparseable response');

  const translations: Record<string, string> = JSON.parse(jsonMatch[0]);

  await prisma.languagePack.create({
    data: {
      gymId: null,
      language,
      data: { _meta: { displayName: targetLanguage, englishName: targetLanguage, countryCode: countryCode.toLowerCase() }, ...translations },
      version: 1,
      isSystemDefault: false,
    },
  });

  logger.info('[LangPackWorker] Pack created', { language });
}
