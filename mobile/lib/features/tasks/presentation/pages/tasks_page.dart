import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/entities/task_entity.dart';
import '../providers/tasks_provider.dart';

class TasksPage extends ConsumerWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);
    final notifier   = ref.read(tasksProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: tasksAsync.when(
                data: (tasks) {
                  final done  = tasks.where((t) => t.isCompleted).length;
                  final total = tasks.length;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Today\'s Tasks',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text('$done / $total complete',
                          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.55))),
                    ],
                  );
                },
                loading: () => const Text('Today\'s Tasks',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                error: (_, __) => const Text('Today\'s Tasks',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                onPressed: () => notifier.load(),
              ),
            ],
          ),

          // ── Progress bar ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: tasksAsync.when(
              data: (tasks) {
                if (tasks.isEmpty) return const SizedBox.shrink();
                final progress = tasks.where((t) => t.isCompleted).length / tasks.length;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          progress == 1.0 ? Colors.greenAccent : AppTheme.primaryBrand),
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms);
              },
              loading: () => const SizedBox.shrink(),
              error:   (_, __) => const SizedBox.shrink(),
            ),
          ),

          // ── Task list ─────────────────────────────────────────────────────────
          tasksAsync.when(
            data: (tasks) {
              if (tasks.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(),
                );
              }
              // Sort: incomplete first, then completed
              final sorted = [...tasks]
                ..sort((a, b) {
                  if (a.isCompleted == b.isCompleted) return 0;
                  return a.isCompleted ? 1 : -1;
                });
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _TaskCard(
                      task: sorted[i],
                      onComplete: () => notifier.completeTask(sorted[i].id),
                    ).animate().fadeIn(delay: (50 * i).ms).slideY(begin: 0.12, end: 0),
                    childCount: sorted.length,
                  ),
                ),
              );
            },
            loading: () => SliverFillRemaining(
              hasScrollBody: false,
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryBrand,
                ),
              ),
            ),
            error: (err, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: _ErrorState(message: err.toString(), onRetry: notifier.load),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

// ── Task Card ──────────────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  final TaskEntity task;
  final VoidCallback onComplete;
  const _TaskCard({required this.task, required this.onComplete});

  IconData get _typeIcon {
    switch (task.type) {
      case TaskType.workoutSession: return Icons.fitness_center_rounded;
      case TaskType.meal:           return Icons.restaurant_rounded;
      case TaskType.custom:         return Icons.check_circle_outline_rounded;
    }
  }

  Color get _typeColor {
    switch (task.type) {
      case TaskType.workoutSession: return const Color(0xFF7C3AED);
      case TaskType.meal:           return const Color(0xFF059669);
      case TaskType.custom:         return const Color(0xFFD97706);
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = task.isCompleted;

    return GestureDetector(
      onTap: done ? null : onComplete,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: done
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.white.withValues(alpha: 0.07),
          border: Border.all(
            color: done ? Colors.white10 : _typeColor.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Type icon bubble
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? Colors.white.withValues(alpha: 0.06)
                      : _typeColor.withValues(alpha: 0.18),
                ),
                child: Icon(
                  done ? Icons.check_circle_rounded : _typeIcon,
                  color: done ? Colors.white30 : _typeColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),

              // Title + description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        color: done ? Colors.white38 : Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                        decoration: done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (task.description != null && task.description!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        task.description!,
                        style: TextStyle(
                          color: done ? Colors.white24 : Colors.white54,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Points badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: done
                      ? Colors.white.withValues(alpha: 0.06)
                      : AppTheme.primaryBrand.withValues(alpha: 0.15),
                ),
                child: Text(
                  '+${task.points}',
                  style: TextStyle(
                    color: done ? Colors.white24 : AppTheme.primaryBrand,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty & Error states ───────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.task_alt_rounded,
              size: 64, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 16),
          Text('All done for today! 🎉',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Your tasks will appear here each day.',
              style:
                  TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13)),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.92, 0.92));
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 48, color: Colors.red.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text('Could not load tasks',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 15)),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.primaryBrand),
          ),
        ],
      ),
    );
  }
}
