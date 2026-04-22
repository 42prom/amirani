import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';
import '../../data/datasources/task_remote_data_source.dart';
import '../../data/repositories/task_repository_impl.dart';
import '../../domain/entities/task_entity.dart';
import '../../domain/repositories/task_repository.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final taskDataSourceProvider = Provider<TaskRemoteDataSource>(
  (ref) => TaskRemoteDataSource(ref.watch(dioProvider)),
);

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepositoryImpl(ref.watch(taskDataSourceProvider)),
);

// ─── State ────────────────────────────────────────────────────────────────────

class TasksNotifier extends StateNotifier<AsyncValue<List<TaskEntity>>> {
  final TaskRepository _repo;
  TasksNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    final result = await _repo.getTodayTasks();
    result.fold(
      (err) => state = AsyncValue.error(err, StackTrace.current),
      (tasks) => state = AsyncValue.data(tasks),
    );
  }

  /// Optimistic toggle — flips local state instantly, then confirms with API.
  Future<void> completeTask(String taskId) async {
    // Optimistic update
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      current.map((t) => t.id == taskId ? t.copyWith(isCompleted: true, completedAt: DateTime.now()) : t).toList(),
    );

    final result = await _repo.completeTask(taskId);
    result.fold(
      (_) => load(), // revert on error
      (updated) {
        final list = state.valueOrNull ?? [];
        state = AsyncValue.data(
          list.map((t) => t.id == taskId ? updated : t).toList(),
        );
      },
    );
  }

  int get completedCount => (state.valueOrNull ?? []).where((t) => t.isCompleted).length;
  int get totalCount => (state.valueOrNull ?? []).length;
}

final tasksProvider =
    StateNotifierProvider<TasksNotifier, AsyncValue<List<TaskEntity>>>(
  (ref) => TasksNotifier(ref.watch(taskRepositoryProvider)),
);
