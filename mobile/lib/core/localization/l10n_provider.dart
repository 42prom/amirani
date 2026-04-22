import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_provider.dart';
import '../providers/storage_providers.dart';
import 'l10n_notifier.dart';
import 'l10n_state.dart';

final l10nProvider = StateNotifierProvider<L10nNotifier, L10nState>((ref) {
  return L10nNotifier(
    ref.read(sharedPreferencesProvider), // pre-initialized in main.dart — synchronous
    ref.read(dioProvider),
  );
});
