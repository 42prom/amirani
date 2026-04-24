import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:amirani_app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  group('Navigation shell', () {
    test('StatefulShellRoute has exactly 5 branches', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(goRouterProvider);

      final shellRoute = router.configuration.routes
          .whereType<StatefulShellRoute>()
          .first;

      expect(
        shellRoute.branches.length,
        equals(5),
        reason:
            'Exactly 5 tabs: Workout, Diet, Challenge, Gym, Dashboard — '
            'no TasksPage, no extra routes',
      );
    });

    test('Shell branches cover the expected paths', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(goRouterProvider);

      final shellRoute = router.configuration.routes
          .whereType<StatefulShellRoute>()
          .first;

      final paths = shellRoute.branches
          .expand((b) => b.routes)
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();

      expect(paths, containsAll(['/workout', '/diet', '/challenge', '/gym', '/dashboard']));
      expect(paths, isNot(contains('/tasks')));
    });
  });
}
