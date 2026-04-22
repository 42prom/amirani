import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:amirani_app/design_system/design_system.dart';
import 'package:amirani_app/theme/app_theme.dart';
import '../../../profile/presentation/providers/profile_sync_provider.dart';
import '../../../profile/presentation/widgets/profile_settings_modal.dart';
import 'package:amirani_app/core/widgets/premium_state_card.dart';
import '../providers/progress_provider.dart';
import '../../../../core/services/mobile_sync_service.dart';

/// Member progress hub — directive 08.
/// Charts: weight trend, calorie trend, habit score timeline, strength PRs.
class ProgressPage extends ConsumerStatefulWidget {
  const ProgressPage({super.key});

  @override
  ConsumerState<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends ConsumerState<ProgressPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    Future.microtask(
      () => ref.read(progressProvider.notifier).load(),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileSync = ref.watch(profileSyncProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(profileSync),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: const [
                  _BodyTab(),
                  _ActivityTab(),
                  _HabitsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ProfileSyncState profileSync) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space24, vertical: AppTokens.space12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => ProfileSettingsModal.show(context),
            child: _AvatarCircle(profileSync: profileSync),
          ),
          const SizedBox(width: AppTokens.space12),
          Text('My Progress', style: AppTokens.textDisplayMd),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: AppTokens.space24, vertical: AppTokens.space8),
      decoration: BoxDecoration(
        color: AppTokens.colorBgSurface,
        borderRadius: BorderRadius.circular(AppTokens.radius12),
        border: Border.all(color: AppTokens.colorBorderSubtle),
      ),
      child: TabBar(
        controller: _tabs,
        indicator: BoxDecoration(
          color: AppTokens.colorBrand,
          borderRadius: BorderRadius.circular(AppTokens.radius10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.black,
        unselectedLabelColor: AppTokens.colorTextSecondary,
        labelStyle: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Body'),
          Tab(text: 'Activity'),
          Tab(text: 'Habits'),
        ],
      ),
    );
  }
}

// ─── Body Tab ─────────────────────────────────────────────────────────────────

class _BodyTab extends ConsumerWidget {
  const _BodyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(progressProvider);

    return RefreshIndicator(
      color: AppTokens.colorBrand,
      onRefresh: () => ref.read(progressProvider.notifier).load(),
      child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space24, vertical: AppTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.error != null && !state.isLoading) ...[
            _ErrorBanner(message: state.error!),
            const SizedBox(height: AppTokens.space16),
          ],
          // Weight trend chart
          Row(
            children: [
              const _SectionHeader(title: 'Weight Trend', subtitle: 'Last 30 days'),
              const Spacer(),
              GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _LogWeightSheet(onSaved: () {
                    ref.read(progressProvider.notifier).load();
                  }),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTokens.colorBrand.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTokens.colorBrand.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 13, color: AppTokens.colorBrand),
                      const SizedBox(width: 4),
                      Text('Log', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTokens.colorBrand)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space12),
          GlassCard(
            padding: const EdgeInsets.fromLTRB(
                AppTokens.space16, AppTokens.space20,
                AppTokens.space16, AppTokens.space12),
            child: state.isLoading
                ? const ShimmerBox.card(height: 160)
                : state.weightLogs.isEmpty
                    ? const _EmptyChart(
                        message: 'Log your weight to see trends')
                    : SizedBox(
                        height: 160,
                        child: _WeightLineChart(
                            logs: state.weightLogs),
                      ),
          ),

          const SizedBox(height: AppTokens.space20),

          // Macro ring summary
          _SectionHeader(title: 'Today\'s Macros', subtitle: 'Calories & split'),
          const SizedBox(height: AppTokens.space12),
          GlassCard(
            child: state.isLoading
                ? const ShimmerStatRow()
                : _MacroRow(macros: state.todayMacros),
          ),

          const SizedBox(height: AppTokens.space20),

          // Body measurements
          _SectionHeader(title: 'Measurements', subtitle: 'cm'),
          const SizedBox(height: AppTokens.space12),
          GlassCard(
            padding: const EdgeInsets.all(AppTokens.space16),
            child: state.isLoading
                ? const ShimmerList(count: 3, itemHeight: 40)
                : state.measurements.isEmpty
                    ? const _EmptyChart(message: 'No measurements logged yet')
                    : _MeasurementTable(
                        measurements: state.measurements),
          ),

          const SizedBox(height: 80),
        ],
      ),
    ).animate().fadeIn(duration: AppTokens.animNormal)); // closes RefreshIndicator
  }
}

// ─── Activity Tab ─────────────────────────────────────────────────────────────

class _ActivityTab extends ConsumerWidget {
  const _ActivityTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(progressProvider);

    return RefreshIndicator(
      color: AppTokens.colorBrand,
      onRefresh: () => ref.read(progressProvider.notifier).load(),
      child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space24, vertical: AppTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.error != null && !state.isLoading) ...[
            _ErrorBanner(message: state.error!),
            const SizedBox(height: AppTokens.space16),
          ],
          // Calories burned trend
          _SectionHeader(
              title: 'Calories Burned', subtitle: 'Last 30 days'),
          const SizedBox(height: AppTokens.space12),
          GlassCard(
            padding: const EdgeInsets.fromLTRB(
                AppTokens.space16, AppTokens.space20,
                AppTokens.space16, AppTokens.space12),
            child: state.isLoading
                ? const ShimmerBox.card(height: 160)
                : SizedBox(
                    height: 160,
                    child: _CaloriesBarChart(
                        data: state.caloriesBurned),
                  ),
          ),

          const SizedBox(height: AppTokens.space20),

          // Weekly summary stats
          _SectionHeader(title: 'This Week', subtitle: 'Workouts & minutes'),
          const SizedBox(height: AppTokens.space12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.fitness_center,
                  value: '${state.workoutsThisWeek}',
                  label: 'Workouts',
                  color: AppTokens.colorScoreWorkout,
                ).animate().fadeIn(delay: 100.ms),
              ),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: _StatCard(
                  icon: Icons.timer_outlined,
                  value: '${state.activeMinutesThisWeek}m',
                  label: 'Active',
                  color: AppTokens.colorSuccess,
                ).animate().fadeIn(delay: 200.ms),
              ),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: _StatCard(
                  icon: Icons.local_fire_department,
                  value: '${state.caloriesBurnedThisWeek}',
                  label: 'Calories',
                  color: AppTokens.colorWarning,
                ).animate().fadeIn(delay: 300.ms),
              ),
            ],
          ),

          const SizedBox(height: 80),
        ],
      ),
    ).animate().fadeIn(duration: AppTokens.animNormal)); // closes RefreshIndicator
  }
}

// ─── Habits Tab ───────────────────────────────────────────────────────────────

class _HabitsTab extends ConsumerWidget {
  const _HabitsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(progressProvider);

    return RefreshIndicator(
      color: AppTokens.colorBrand,
      onRefresh: () => ref.read(progressProvider.notifier).load(),
      child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space24, vertical: AppTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.error != null && !state.isLoading) ...[
            _ErrorBanner(message: state.error!),
            const SizedBox(height: AppTokens.space16),
          ],
          // Score ring cluster
          _SectionHeader(
              title: 'Behavioral Scores', subtitle: 'Today\'s snapshot'),
          const SizedBox(height: AppTokens.space16),
          GlassCard(
            child: ScoreRingCluster(
              workoutScore: state.workoutScore,
              dietScore: state.dietScore,
              hydrationScore: state.hydrationScore,
              sleepScore: state.sleepScore,
            ),
          ),

          const SizedBox(height: AppTokens.space20),

          // 30-day habit timeline
          _SectionHeader(
              title: 'Score Timeline', subtitle: '30-day area chart'),
          const SizedBox(height: AppTokens.space12),
          GlassCard(
            padding: const EdgeInsets.fromLTRB(
                AppTokens.space16, AppTokens.space20,
                AppTokens.space16, AppTokens.space12),
            child: state.isLoading
                ? const ShimmerBox.card(height: 160)
                : state.habitTimeline.isEmpty
                    ? const _EmptyChart(
                        message: 'Keep logging to build your timeline')
                    : SizedBox(
                        height: 160,
                        child: _HabitAreaChart(
                            data: state.habitTimeline),
                      ),
          ),

          const SizedBox(height: 80),
        ],
      ),
    ).animate().fadeIn(duration: AppTokens.animNormal)); // closes RefreshIndicator
  }
}

// ─── Charts ───────────────────────────────────────────────────────────────────

class _WeightLineChart extends StatelessWidget {
  const _WeightLineChart({required this.logs});
  final List<WeightLog> logs;

  @override
  Widget build(BuildContext context) {
    final spots = logs.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.weightKg);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.white.withValues(alpha: 0.05),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, _) => Text(
                '${value.toInt()}',
                style: AppTokens.textCaption,
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppTokens.colorBrand,
            barWidth: 2.5,
            dotData: FlDotData(show: spots.length < 10),
            belowBarData: BarAreaData(
              show: true,
              color: AppTokens.colorBrand.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
      duration: AppTokens.animChart,
    );
  }
}

class _CaloriesBarChart extends StatelessWidget {
  const _CaloriesBarChart({required this.data});
  final List<double> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const _EmptyChart(message: 'No activity yet');

    return BarChart(
      BarChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.white.withValues(alpha: 0.05),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: data.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value,
                color: AppTokens.colorBrand,
                width: 6,
                borderRadius: BorderRadius.circular(4),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: data.reduce((a, b) => a > b ? a : b) * 1.2,
                  color: AppTokens.colorBrand.withValues(alpha: 0.06),
                ),
              ),
            ],
          );
        }).toList(),
      ),
      duration: AppTokens.animChart,
    );
  }
}

class _HabitAreaChart extends StatelessWidget {
  const _HabitAreaChart({required this.data});
  final List<HabitScorePoint> data;

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.white.withValues(alpha: 0.05),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: 1,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          _areaLine(
              data.asMap().entries
                  .map((e) => FlSpot(e.key.toDouble(), e.value.workout))
                  .toList(),
              AppTokens.colorScoreWorkout),
          _areaLine(
              data.asMap().entries
                  .map((e) => FlSpot(e.key.toDouble(), e.value.diet))
                  .toList(),
              AppTokens.colorScoreDiet),
          _areaLine(
              data.asMap().entries
                  .map((e) =>
                      FlSpot(e.key.toDouble(), e.value.hydration))
                  .toList(),
              AppTokens.colorScoreHydration),
          _areaLine(
              data.asMap().entries
                  .map((e) => FlSpot(e.key.toDouble(), e.value.sleep))
                  .toList(),
              AppTokens.colorScoreSleep),
        ],
      ),
      duration: AppTokens.animChart,
    );
  }

  LineChartBarData _areaLine(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 1.5,
      dotData: FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.06),
      ),
    );
  }
}

// ─── Supporting Widgets ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(title, style: AppTokens.textHeadingLg),
        const SizedBox(width: AppTokens.space8),
        Text(subtitle, style: AppTokens.textBodyMd),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade700.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade400, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(color: Colors.red.shade300, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: PremiumStateCard(
        icon: Icons.bar_chart_rounded,
        title: 'No Data Yet',
        subtitle: message,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppTokens.space16),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: AppTokens.space8),
          Text(value,
              style: AppTokens.textHeadingLg.copyWith(color: color)),
          Text(label, style: AppTokens.textCaption),
        ],
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({required this.macros});
  final TodayMacros macros;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _MacroItem(label: 'Calories', value: '${macros.calories}',
            unit: 'kcal', color: AppTokens.colorBrand),
        _MacroItem(label: 'Protein', value: '${macros.proteinG}g',
            unit: '', color: AppTokens.colorScoreDiet),
        _MacroItem(label: 'Carbs', value: '${macros.carbsG}g',
            unit: '', color: AppTokens.colorScoreHydration),
        _MacroItem(label: 'Fat', value: '${macros.fatG}g',
            unit: '', color: AppTokens.colorScoreSleep),
      ],
    );
  }
}

class _MacroItem extends StatelessWidget {
  const _MacroItem({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });
  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          unit.isEmpty ? value : '$value $unit',
          style: AppTokens.textHeadingMd.copyWith(color: color),
        ),
        const SizedBox(height: AppTokens.space4),
        Text(label, style: AppTokens.textCaption),
      ],
    );
  }
}

class _MeasurementTable extends StatelessWidget {
  const _MeasurementTable({required this.measurements});
  final List<MeasurementEntry> measurements;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: measurements.map<Widget>((MeasurementEntry m) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTokens.space6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(m.label, style: AppTokens.textBodyMd),
              Text(
                '${m.value} ${m.unit}',
                style: AppTokens.textBodyLg.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.profileSync});
  final ProfileSyncState profileSync;

  @override
  Widget build(BuildContext context) {
    final path = profileSync.profileImagePath;
    return Container(
      height: 36,
      width: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTokens.colorBgSurface,
        border: Border.all(color: AppTokens.colorBorderSubtle),
        image: path != null
            ? DecorationImage(
                image: FileImage(File(path)),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: path == null
          ? const Icon(Icons.person, color: Colors.white54, size: 20)
          : null,
    );
  }
}

// ─── Log Weight Sheet ──────────────────────────────────────────────────────────

class _LogWeightSheet extends ConsumerStatefulWidget {
  const _LogWeightSheet({required this.onSaved});
  final VoidCallback onSaved;

  @override
  ConsumerState<_LogWeightSheet> createState() => _LogWeightSheetState();
}

class _LogWeightSheetState extends ConsumerState<_LogWeightSheet> {
  final _controller = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _controller.text.trim();
    final kg = double.tryParse(raw);
    if (kg == null || kg <= 0 || kg > 500) {
      setState(() => _error = 'Enter a valid weight (kg)');
      return;
    }
    setState(() { _saving = true; _error = null; });
    final svc = ref.read(mobileSyncServiceProvider);
    await svc.syncUp(profileChanges: {'weight': kg.toString()});
    if (!mounted) return;
    widget.onSaved();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 32 + bottom),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Log Weight', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Update your current body weight', style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 14)),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'e.g. 75.5',
              hintStyle: TextStyle(color: Colors.white38),
              suffixText: 'kg',
              suffixStyle: TextStyle(color: Colors.white54),
              errorText: _error,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.07),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTokens.colorBrand,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
