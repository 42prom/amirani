import 'en_strings.dart';
import 'l10n_notifier.dart';

/// Type-safe translation access for the entire app.
///
/// Usage in any ConsumerWidget:
///   ref.watch(l10nProvider); // subscribe to rebuilds
///   Text(L10n.buttonSave)    // type-safe, IDE-autocompleted
///
/// Wire once in AmiraniApp.initState:
///   L10n.init(ref.read(l10nProvider.notifier));
abstract class L10n {
  static L10nNotifier? _svc;

  /// Called once in AmiraniApp.initState after the provider tree is ready.
  static void init(L10nNotifier notifier) => _svc = notifier;

  /// Raw translate — use typed getters below instead.
  static String tr(String key) => _svc?.tr(key) ?? kEn[key] ?? key;

  /// Translate with named placeholder substitution.
  /// Example: L10n.trArgs('workout.log_set', {'n': '2', 'total': '4'})
  static String trArgs(String key, Map<String, String> args) =>
      _svc?.trArgs(key, args) ?? (() {
        var s = kEn[key] ?? key;
        args.forEach((k, v) => s = s.replaceAll('{$k}', v));
        return s;
      })();

  // ── Common buttons ────────────────────────────────────────────────────────
  static String get buttonSave      => tr('button.save');
  static String get buttonCancel    => tr('button.cancel');
  static String get buttonConfirm   => tr('button.confirm');
  static String get buttonDelete    => tr('button.delete');
  static String get buttonEdit      => tr('button.edit');
  static String get buttonBack      => tr('button.back');
  static String get buttonNext      => tr('button.next');
  static String get buttonDone      => tr('button.done');
  static String get buttonRetry     => tr('button.retry');
  static String get buttonClose     => tr('button.close');
  static String get buttonSubmit    => tr('button.submit');
  static String get buttonContinue  => tr('button.continue');
  static String get buttonSkip      => tr('button.skip');
  static String get buttonAdd       => tr('button.add');
  static String get buttonRemove    => tr('button.remove');
  static String get buttonUpdate    => tr('button.update');
  static String get buttonApply     => tr('button.apply');
  static String get buttonGenerate  => tr('button.generate');
  static String get buttonRefresh   => tr('button.refresh');

  // ── Auth ──────────────────────────────────────────────────────────────────
  static String get authLogin             => tr('auth.login');
  static String get authLogout            => tr('auth.logout');
  static String get authEmail             => tr('auth.email');
  static String get authPassword          => tr('auth.password');
  static String get authConfirmPassword   => tr('auth.confirm_password');
  static String get authForgotPassword    => tr('auth.forgot_password');
  static String get authResetPassword     => tr('auth.reset_password');
  static String get authChangePassword    => tr('auth.change_password');
  static String get authNewPassword       => tr('auth.new_password');
  static String get authOldPassword       => tr('auth.old_password');
  static String get authSignInGoogle      => tr('auth.sign_in_google');
  static String get authSignInApple       => tr('auth.sign_in_apple');
  static String get authNoAccount         => tr('auth.no_account');
  static String get authHasAccount        => tr('auth.has_account');
  static String get authRegister          => tr('auth.register');
  static String get authWelcomeBack       => tr('auth.welcome_back');
  static String get authEnterEmail        => tr('auth.enter_email');
  static String get authEnterPassword     => tr('auth.enter_password');
  static String get authPasswordChanged   => tr('auth.password_changed');

  // ── Navigation ────────────────────────────────────────────────────────────
  static String get navHome       => tr('nav.home');
  static String get navWorkout    => tr('nav.workout');
  static String get navDiet       => tr('nav.diet');
  static String get navGym        => tr('nav.gym');
  static String get navDashboard  => tr('nav.dashboard');
  static String get navChallenge  => tr('nav.challenge');
  static String get navProgress   => tr('nav.progress');
  static String get navProfile    => tr('nav.profile');
  static String get navSettings   => tr('nav.settings');

  // ── Dashboard ─────────────────────────────────────────────────────────────
  static String get dashboardTitle        => tr('dashboard.title');
  static String get dashboardGoodMorning  => tr('dashboard.good_morning');
  static String get dashboardGoodAfternoon=> tr('dashboard.good_afternoon');
  static String get dashboardGoodEvening  => tr('dashboard.good_evening');
  static String get dashboardWeeklySummary=> tr('dashboard.weekly_summary');
  static String get dashboardTodaysGoal   => tr('dashboard.todays_goal');
  static String get dashboardStreak       => tr('dashboard.streak');
  static String get dashboardCalories     => tr('dashboard.calories');
  static String get dashboardSteps        => tr('dashboard.steps');
  static String get dashboardWater        => tr('dashboard.water');
  static String get dashboardSleep        => tr('dashboard.sleep');
  static String get dashboardRecovery     => tr('dashboard.recovery');
  static String get dashboardReadiness    => tr('dashboard.readiness');
  static String get dashboardNoData       => tr('dashboard.no_data');

  // ── Workout ───────────────────────────────────────────────────────────────
  static String get workoutTitle          => tr('workout.title');
  static String get workoutStart          => tr('workout.start');
  static String get workoutPause          => tr('workout.pause');
  static String get workoutResume         => tr('workout.resume');
  static String get workoutFinish         => tr('workout.finish');
  static String get workoutSets           => tr('workout.sets');
  static String get workoutReps           => tr('workout.reps');
  static String get workoutWeight         => tr('workout.weight');
  static String get workoutRest           => tr('workout.rest');
  static String get workoutDuration       => tr('workout.duration');
  static String get workoutActiveSession  => tr('workout.active_session');
  static String get workoutNoPlan         => tr('workout.no_plan');
  static String get workoutComplete       => tr('workout.complete');

  // ── Diet ──────────────────────────────────────────────────────────────────
  static String get dietTitle         => tr('diet.title');
  static String get dietGeneratePlan  => tr('diet.generate_plan');
  static String get dietCalories      => tr('diet.calories');
  static String get dietProtein       => tr('diet.protein');
  static String get dietCarbs         => tr('diet.carbs');
  static String get dietFat           => tr('diet.fat');
  static String get dietBreakfast     => tr('diet.breakfast');
  static String get dietLunch         => tr('diet.lunch');
  static String get dietDinner        => tr('diet.dinner');
  static String get dietSnack         => tr('diet.snack');
  static String get dietWaterIntake   => tr('diet.water_intake');
  static String get dietNoPlan        => tr('diet.no_plan');
  static String get dietDailyTarget   => tr('diet.daily_target');

  // ── Gym ───────────────────────────────────────────────────────────────────
  static String get gymTitle      => tr('gym.title');
  static String get gymJoin       => tr('gym.join');
  static String get gymLeave      => tr('gym.leave');
  static String get gymMembers    => tr('gym.members');
  static String get gymTrainer    => tr('gym.trainer');
  static String get gymSchedule   => tr('gym.schedule');
  static String get gymMembership => tr('gym.membership');
  static String get gymActive     => tr('gym.active');
  static String get gymExpired    => tr('gym.expired');
  static String get gymPending    => tr('gym.pending');
  static String get gymNoGym      => tr('gym.no_gym');
  static String get gymScanQr     => tr('gym.scan_qr');
  static String get gymRegister   => tr('gym.register');

  // ── Settings ──────────────────────────────────────────────────────────────
  static String get settingsTitle                => tr('settings.title');
  static String get settingsLanguage             => tr('settings.language');
  static String get settingsDownloadingLanguage  => tr('settings.downloading_language');
  static String get settingsLanguageUnavailable  => tr('settings.language_unavailable');
  static String get settingsProfile              => tr('settings.profile');
  static String get settingsNotifications        => tr('settings.notifications');
  static String get settingsPrivacy              => tr('settings.privacy');
  static String get settingsAbout                => tr('settings.about');
  static String get settingsVersion              => tr('settings.version');
  static String get settingsLogout               => tr('settings.logout');
  static String get settingsDeleteAccount        => tr('settings.delete_account');

  // ── Profile ───────────────────────────────────────────────────────────────
  static String get profileTitle       => tr('profile.title');
  static String get profileFirstName   => tr('profile.first_name');
  static String get profileLastName    => tr('profile.last_name');
  static String get profilePhone       => tr('profile.phone');
  static String get profileDob         => tr('profile.dob');
  static String get profileGender      => tr('profile.gender');
  static String get profileWeight      => tr('profile.weight');
  static String get profileHeight      => tr('profile.height');
  static String get profileEditPhoto   => tr('profile.edit_photo');
  static String get profileSaveChanges => tr('profile.save_changes');

  // ── Errors ────────────────────────────────────────────────────────────────
  static String get errorGeneric            => tr('error.generic');
  static String get errorNetwork            => tr('error.network');
  static String get errorSessionExpired     => tr('error.session_expired');
  static String get errorInvalidCredentials => tr('error.invalid_credentials');
  static String get errorRequiredField      => tr('error.required_field');
  static String get errorInvalidEmail       => tr('error.invalid_email');
  static String get errorPasswordTooShort   => tr('error.password_too_short');
  static String get errorPasswordsNoMatch   => tr('error.passwords_no_match');
  static String get errorServer             => tr('error.server');

  // ── Common labels ─────────────────────────────────────────────────────────
  static String get labelLoading    => tr('label.loading');
  static String get labelNoResults  => tr('label.no_results');
  static String get labelToday      => tr('label.today');
  static String get labelYesterday  => tr('label.yesterday');
  static String get labelThisWeek   => tr('label.this_week');
  static String get labelOptional   => tr('label.optional');
  static String get labelRequired   => tr('label.required');
  static String get labelOr         => tr('label.or');
  static String get labelSearch     => tr('label.search');
  static String get labelFilter     => tr('label.filter');
  static String get labelSort       => tr('label.sort');
  static String get labelAll        => tr('label.all');
  static String get labelActive     => tr('label.active');
  static String get labelInactive   => tr('label.inactive');

  // ── Onboarding ────────────────────────────────────────────────────────────
  static String get onboardingGetStarted  => tr('onboarding.get_started');
  static String get onboardingWelcome     => tr('onboarding.welcome');
  static String get onboardingSubtitle    => tr('onboarding.subtitle');

  // ── Challenge ─────────────────────────────────────────────────────────────
  static String get challengeBonusChallenges => tr('challenge.bonus_challenges');
  static String get challengeHydrationToday  => tr('challenge.hydration_today');
  static String get challengeGoalMet         => tr('challenge.goal_met');
}
