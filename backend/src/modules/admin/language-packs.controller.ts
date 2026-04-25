import { Router, Response } from 'express';
import prisma from '../../lib/prisma';
import logger from '../../lib/logger';
import { authenticate, superAdminOnly, AuthenticatedRequest } from '../../middleware/auth.middleware';
import { success, badRequest, notFound, internalError, created } from '../../utils/response';
import Anthropic from '@anthropic-ai/sdk';

const router = Router();
router.use(authenticate, superAdminOnly);

// ── English strings — mirrors mobile/lib/core/localization/en_strings.dart ────
const EN_STRINGS: Record<string, string> = {
  'button.save': 'Save',
  'button.cancel': 'Cancel',
  'button.confirm': 'Confirm',
  'button.delete': 'Delete',
  'button.edit': 'Edit',
  'button.back': 'Back',
  'button.next': 'Next',
  'button.done': 'Done',
  'button.retry': 'Retry',
  'button.close': 'Close',
  'button.submit': 'Submit',
  'button.continue': 'Continue',
  'button.skip': 'Skip',
  'button.add': 'Add',
  'button.remove': 'Remove',
  'button.update': 'Update',
  'button.apply': 'Apply',
  'button.generate': 'Generate',
  'button.refresh': 'Refresh',
  'auth.login': 'Login',
  'auth.logout': 'Logout',
  'auth.email': 'Email',
  'auth.password': 'Password',
  'auth.confirm_password': 'Confirm Password',
  'auth.forgot_password': 'Forgot Password?',
  'auth.reset_password': 'Reset Password',
  'auth.change_password': 'Change Password',
  'auth.new_password': 'New Password',
  'auth.old_password': 'Current Password',
  'auth.sign_in_google': 'Continue with Google',
  'auth.sign_in_apple': 'Continue with Apple',
  'auth.no_account': "Don't have an account?",
  'auth.has_account': 'Already have an account?',
  'auth.register': 'Register',
  'auth.welcome_back': 'Welcome Back',
  'auth.enter_email': 'Enter your email',
  'auth.enter_password': 'Enter your password',
  'auth.password_changed': 'Password changed successfully',
  'nav.home': 'Home',
  'nav.workout': 'Workout',
  'nav.diet': 'Diet',
  'nav.gym': 'Gym',
  'nav.dashboard': 'Dashboard',
  'nav.challenge': 'Challenge',
  'nav.progress': 'Progress',
  'nav.profile': 'Profile',
  'nav.settings': 'Settings',
  'dashboard.title': 'Dashboard',
  'dashboard.good_morning': 'Good Morning',
  'dashboard.good_afternoon': 'Good Afternoon',
  'dashboard.good_evening': 'Good Evening',
  'dashboard.weekly_summary': 'Weekly Summary',
  'dashboard.todays_goal': "Today's Goal",
  'dashboard.streak': 'Streak',
  'dashboard.calories': 'Calories',
  'dashboard.steps': 'Steps',
  'dashboard.water': 'Water',
  'dashboard.sleep': 'Sleep',
  'dashboard.recovery': 'Recovery',
  'dashboard.readiness': 'Readiness',
  'dashboard.no_data': 'No data yet',
  'workout.title': 'Workout',
  'workout.start': 'Start Workout',
  'workout.pause': 'Pause',
  'workout.resume': 'Resume',
  'workout.finish': 'Finish Workout',
  'workout.sets': 'Sets',
  'workout.reps': 'Reps',
  'workout.weight': 'Weight',
  'workout.rest': 'Rest',
  'workout.duration': 'Duration',
  'workout.active_session': 'Active Session',
  'workout.no_plan': 'No workout plan assigned',
  'workout.complete': 'Complete',
  'diet.title': 'Diet',
  'diet.generate_plan': 'Generate Diet Plan',
  'diet.calories': 'Calories',
  'diet.protein': 'Protein',
  'diet.carbs': 'Carbs',
  'diet.fat': 'Fat',
  'diet.breakfast': 'Breakfast',
  'diet.lunch': 'Lunch',
  'diet.dinner': 'Dinner',
  'diet.snack': 'Snack',
  'diet.water_intake': 'Water Intake',
  'diet.no_plan': 'No diet plan assigned',
  'diet.daily_target': 'Daily Target',
  'gym.title': 'Gym',
  'gym.join': 'Join Gym',
  'gym.leave': 'Leave Gym',
  'gym.members': 'Members',
  'gym.trainer': 'Trainer',
  'gym.schedule': 'Schedule',
  'gym.membership': 'Membership',
  'gym.active': 'Active',
  'gym.expired': 'Expired',
  'gym.pending': 'Pending Approval',
  'gym.no_gym': 'Not a member of any gym',
  'gym.scan_qr': 'Scan QR Code',
  'gym.register': 'Register with Gym',
  'settings.title': 'Settings',
  'settings.language': 'Language',
  'settings.downloading_language': 'Downloading language...',
  'settings.language_unavailable': 'Language unavailable offline. Connect to download.',
  'settings.profile': 'Profile',
  'settings.notifications': 'Notifications',
  'settings.privacy': 'Privacy',
  'settings.about': 'About',
  'settings.version': 'Version',
  'settings.logout': 'Logout',
  'settings.delete_account': 'Delete Account',
  'profile.title': 'Profile',
  'profile.first_name': 'First Name',
  'profile.last_name': 'Last Name',
  'profile.phone': 'Phone Number',
  'profile.dob': 'Date of Birth',
  'profile.gender': 'Gender',
  'profile.weight': 'Weight (kg)',
  'profile.height': 'Height (cm)',
  'profile.edit_photo': 'Edit Photo',
  'profile.save_changes': 'Save Changes',
  'error.generic': 'Something went wrong. Please try again.',
  'error.network': 'No internet connection.',
  'error.session_expired': 'Session expired. Please log in again.',
  'error.invalid_credentials': 'Invalid email or password.',
  'error.required_field': 'This field is required.',
  'error.invalid_email': 'Please enter a valid email.',
  'error.password_too_short': 'Password must be at least 8 characters.',
  'error.passwords_no_match': 'Passwords do not match.',
  'error.server': 'Server error. Please try again later.',
  'label.loading': 'Loading...',
  'label.no_results': 'No results found.',
  'label.today': 'Today',
  'label.yesterday': 'Yesterday',
  'label.this_week': 'This Week',
  'label.optional': 'Optional',
  'label.required': 'Required',
  'label.or': 'or',
  'label.search': 'Search',
  'label.filter': 'Filter',
  'label.sort': 'Sort',
  'label.all': 'All',
  'label.active': 'Active',
  'label.inactive': 'Inactive',
  'onboarding.get_started': 'Get Started',
  'onboarding.welcome': 'Welcome to Amirani',
  'onboarding.subtitle': 'Your Personal Fitness Platform',
};

const LANG_TO_COUNTRY: Record<string, string> = {
  ka: 'ge', ru: 'ru', uk: 'ua', de: 'de', fr: 'fr', es: 'es',
  it: 'it', pt: 'pt', ar: 'sa', zh: 'cn', ja: 'jp', ko: 'kr',
  tr: 'tr', pl: 'pl', nl: 'nl', sv: 'se', no: 'no', da: 'dk',
  fi: 'fi', cs: 'cz', ro: 'ro', hu: 'hu', el: 'gr', he: 'il',
  hi: 'in', th: 'th', vi: 'vn', id: 'id', ms: 'my',
};

type PackData = Record<string, string> & { _meta?: { displayName?: string; englishName?: string; countryCode?: string } };

function packToDto(pack: { id: string; language: string; data: unknown; version: number; isSystemDefault: boolean }, gymCount: number) {
  const data = (pack.data as PackData) ?? {};
  const meta = data._meta;
  const code = pack.language.toLowerCase();
  return {
    code,
    displayName: meta?.displayName ?? pack.language,
    englishName: meta?.englishName ?? pack.language,
    countryCode: meta?.countryCode ?? LANG_TO_COUNTRY[code] ?? code,
    version: pack.version,
    gymCount,
    isPublished: pack.isSystemDefault,
    isDraft: !pack.isSystemDefault,
  };
}

// ── GET /admin/language-packs ─────────────────────────────────────────────────
router.get('/', async (_req: AuthenticatedRequest, res: Response) => {
  try {
    const [packs, gymCounts] = await Promise.all([
      prisma.languagePack.findMany({
        where: { gymId: null },
        orderBy: { updatedAt: 'desc' },
      }),
      prisma.languagePack.groupBy({
        by: ['language'],
        where: { gymId: { not: null } },
        _count: { gymId: true },
      }),
    ]);
    const gymCountMap = Object.fromEntries(gymCounts.map((g) => [g.language, g._count.gymId]));
    return success(res, { packs: packs.map((p) => packToDto(p, gymCountMap[p.language] ?? 0)) });
  } catch (err) {
    logger.error('[LangPacks] list error', { err });
    internalError(res);
  }
});

// ── POST /admin/language-packs/ai-generate (before /:code) ───────────────────
router.post('/ai-generate', async (req: AuthenticatedRequest, res: Response) => {
  const { targetLanguage, languageCode, countryCode } = req.body ?? {};
  if (!targetLanguage || !languageCode || String(languageCode).trim().length < 2) {
    return badRequest(res, 'targetLanguage and languageCode (min 2 chars) are required');
  }
  const lang = String(languageCode).trim().toUpperCase();

  try {
    const existing = await prisma.languagePack.findFirst({ where: { gymId: null, language: lang } });
    if (existing) return badRequest(res, `Pack for '${lang}' already exists. Edit it directly.`);

    const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
    const aiRes = await client.messages.create({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 8192,
      messages: [
        {
          role: 'user',
          content: `Translate these English mobile app UI strings into ${targetLanguage}. Rules: keep translations SHORT and UI-friendly (buttons/labels/menus), do not add notes, return ONLY a valid JSON object with the same keys.\n\n${JSON.stringify(EN_STRINGS)}`,
        },
      ],
    });

    const rawText = aiRes.content[0].type === 'text' ? aiRes.content[0].text : '';
    const jsonMatch = rawText.match(/\{[\s\S]*\}/);
    if (!jsonMatch) return internalError(res, 'AI returned unparseable response');

    let translations: Record<string, string>;
    try {
      translations = JSON.parse(jsonMatch[0]);
    } catch {
      return internalError(res, 'AI returned invalid JSON');
    }

    const meta = {
      displayName: String(targetLanguage).trim(),
      englishName: String(targetLanguage).trim(),
      countryCode: (String(countryCode || LANG_TO_COUNTRY[String(languageCode).toLowerCase()] || languageCode).toLowerCase()),
    };

    const pack = await prisma.languagePack.create({
      data: { gymId: null, language: lang, data: { _meta: meta, ...translations }, version: 1, isSystemDefault: false },
    });

    logger.info('[LangPacks] AI pack created', { language: lang });
    return success(res, packToDto(pack, 0), undefined, 201);
  } catch (err: any) {
    logger.error('[LangPacks] ai-generate error', { err: err.message });
    internalError(res);
  }
});

// ── GET /admin/language-packs/:code ──────────────────────────────────────────
router.get('/:code', async (req: AuthenticatedRequest, res: Response) => {
  const lang = req.params.code.toUpperCase();
  try {
    const pack = await prisma.languagePack.findFirst({ where: { gymId: null, language: lang } });
    if (!pack) return notFound(res, 'Language pack not found');

    const data = (pack.data as PackData) ?? {};
    const { _meta, ...translations } = data;

    const rows = Object.entries(EN_STRINGS).map(([key, english]) => ({
      key,
      english,
      translation: (translations as Record<string, string>)[key] ?? '',
      isMissing: !(translations as Record<string, string>)[key],
    }));

    const gymCount = await prisma.languagePack.count({ where: { gymId: { not: null }, language: lang } });

    return success(res, {
      ...packToDto(pack, gymCount),
      rows,
      totalKeys: rows.length,
      translatedKeys: rows.filter((r) => !r.isMissing).length,
      missingKeys: rows.filter((r) => r.isMissing).length,
    });
  } catch (err) {
    logger.error('[LangPacks] get detail error', { err });
    internalError(res);
  }
});

// ── PATCH /admin/language-packs/:code ────────────────────────────────────────
// Handles both: { translations: {...} } to save edits, or { isPublished: bool } to toggle
router.patch('/:code', async (req: AuthenticatedRequest, res: Response) => {
  const lang = req.params.code.toUpperCase();
  const { translations, isPublished } = req.body ?? {};

  try {
    const existing = await prisma.languagePack.findFirst({ where: { gymId: null, language: lang } });
    if (!existing) return notFound(res, 'Language pack not found');

    const gymCount = await prisma.languagePack.count({ where: { gymId: { not: null }, language: lang } });

    if (isPublished !== undefined) {
      const updated = await prisma.languagePack.update({
        where: { id: existing.id },
        data: { isSystemDefault: Boolean(isPublished) },
      });
      return success(res, packToDto(updated, gymCount));
    }

    if (translations && typeof translations === 'object') {
      const currentData = (existing.data as PackData) ?? {};
      const updated = await prisma.languagePack.update({
        where: { id: existing.id },
        data: { data: { ...currentData, ...translations }, version: { increment: 1 } },
      });
      return success(res, packToDto(updated, gymCount));
    }

    return badRequest(res, 'Provide translations or isPublished');
  } catch (err) {
    logger.error('[LangPacks] patch error', { err });
    internalError(res);
  }
});

// ── POST /admin/language-packs/:code/push ────────────────────────────────────
// Publish system default + overwrite all gym-specific packs with same data
router.post('/:code/push', async (req: AuthenticatedRequest, res: Response) => {
  const lang = req.params.code.toUpperCase();
  try {
    const systemPack = await prisma.languagePack.findFirst({ where: { gymId: null, language: lang } });
    if (!systemPack) return notFound(res, 'Language pack not found');

    const [, pushResult] = await prisma.$transaction([
      prisma.languagePack.update({
        where: { id: systemPack.id },
        data: { isSystemDefault: true },
      }),
      prisma.languagePack.updateMany({
        where: { gymId: { not: null }, language: lang },
        data: { data: systemPack.data as any, version: systemPack.version },
      }),
    ]);

    logger.info('[LangPacks] pushed to gyms', { language: lang, count: pushResult.count });
    return success(res, { pushed: pushResult.count, published: true });
  } catch (err) {
    logger.error('[LangPacks] push error', { err });
    internalError(res);
  }
});

export default router;
