import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:amirani_app/design_system/tokens/app_tokens.dart';
import '../../../../core/services/daily_snapshot_service.dart';

class ScoreHistoryChart extends ConsumerStatefulWidget {
  const ScoreHistoryChart({super.key});

  @override
  ConsumerState<ScoreHistoryChart> createState() => _ScoreHistoryChartState();
}

class _ScoreHistoryChartState extends ConsumerState<ScoreHistoryChart> {
  final ScreenshotController _screenshotController = ScreenshotController();
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(scoreHistoryProvider);

    return Screenshot(
      controller: _screenshotController,
      child: Container(
        decoration: BoxDecoration(
          color: AppTokens.colorBgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildPeriodToggle(history.period),
            const SizedBox(height: 20),
            _buildChart(history),
            const SizedBox(height: 16),
            _buildStats(history),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Score History',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        GestureDetector(
          onTap: _saveChart,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTokens.colorBrand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppTokens.colorBrand.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.download_outlined,
                    size: 13, color: AppTokens.colorBrand),
                const SizedBox(width: 5),
                Text(
                  'Save',
                  style: TextStyle(
                      color: AppTokens.colorBrand,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodToggle(HistoryPeriod current) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: AppTokens.colorBgPrimary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: HistoryPeriod.values.map((p) {
          final isActive = p == current;
          final label = switch (p) {
            HistoryPeriod.week => 'Week',
            HistoryPeriod.month => 'Month',
            HistoryPeriod.year => 'Year',
          };
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _touchedIndex = null);
                ref.read(scoreHistoryProvider.notifier).load(p);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppTokens.colorBrand.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isActive
                      ? Border.all(
                          color: AppTokens.colorBrand.withValues(alpha: 0.5))
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    color: isActive ? AppTokens.colorBrand : Colors.white38,
                    fontSize: 12,
                    fontWeight:
                        isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChart(ScoreHistoryState history) {
    if (history.bars.isEmpty) {
      return const SizedBox(
        height: 140,
        child: Center(
          child: Text('No data yet',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
        ),
      );
    }

    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
          minY: 0,
          barTouchData: BarTouchData(
            enabled: true,
            touchCallback: (event, response) {
              if (event is FlTapUpEvent || event is FlPanEndEvent) {
                setState(() {
                  _touchedIndex =
                      response?.spot?.touchedBarGroupIndex;
                });
              }
            },
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppTokens.colorBgSurface,
              tooltipPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              tooltipRoundedRadius: 10,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final bar = history.bars[groupIndex];
                if (!bar.hasAnyData) return null;
                final lines = <String>[];
                lines.add('Overall: ${bar.overall}%');
                if (bar.workout != null) lines.add('Workout: ${bar.workout}%');
                if (bar.diet != null) lines.add('Diet: ${bar.diet}%');
                if (bar.gymMinutes != null && bar.gymMinutes! > 0) {
                  lines.add('Gym: ${bar.gymMinutes}min');
                }
                return BarTooltipItem(
                  lines.join('\n'),
                  const TextStyle(
                      color: Colors.white, fontSize: 11, height: 1.5),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= history.bars.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      history.bars[i].label,
                      style: TextStyle(
                        color: i == _touchedIndex
                            ? AppTokens.colorBrand
                            : Colors.white38,
                        fontSize: 10,
                        fontWeight: i == _touchedIndex
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  );
                },
                reservedSize: 22,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 50,
                getTitlesWidget: (value, meta) => Text(
                  '${value.toInt()}',
                  style: const TextStyle(color: Colors.white24, fontSize: 9),
                ),
                reservedSize: 24,
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 50,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.white.withValues(alpha: 0.05),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: history.bars.asMap().entries.map((entry) {
            final i = entry.key;
            final bar = entry.value;
            final isTouched = i == _touchedIndex;
            final barColor = _scoreColor(bar.overall, bar.hasAnyData);
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: bar.hasAnyData ? bar.overall.toDouble() : 0,
                  width: isTouched ? 14 : 11,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(5)),
                  color: isTouched
                      ? barColor
                      : barColor.withValues(alpha: 0.75),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: 100,
                    color: Colors.white.withValues(alpha: 0.03),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
        duration: const Duration(milliseconds: 300),
      ),
    );
  }

  Widget _buildStats(ScoreHistoryState history) {
    return Row(
      children: [
        _statChip(
          icon: Icons.emoji_events_outlined,
          label: 'Best',
          value: '${history.bestScore}%',
          color: AppTokens.colorBrand,
        ),
        const SizedBox(width: 10),
        _statChip(
          icon: Icons.trending_up,
          label: 'Avg',
          value: '${history.avgScore}%',
          color: const Color(0xFF6366F1),
        ),
        const SizedBox(width: 10),
        _statChip(
          icon: Icons.fitness_center_outlined,
          label: 'Gym',
          value: _formatMinutes(history.totalGymMinutes),
          color: const Color(0xFF2ECC71),
        ),
      ],
    );
  }

  Widget _statChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
            Text(label,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Color _scoreColor(int score, bool hasData) {
    if (!hasData) return Colors.white12;
    if (score >= 70) return AppTokens.colorBrand;
    if (score >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFFF43F5E);
  }

  String _formatMinutes(int total) {
    if (total == 0) return '—';
    if (total < 60) return '${total}m';
    final h = total ~/ 60;
    final m = total % 60;
    return m == 0 ? '${h}h' : '${h}h${m}m';
  }

  Future<void> _saveChart() async {
    try {
      final bytes = await _screenshotController.capture(pixelRatio: 2.5);
      if (bytes == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/amirani_progress_$ts.png');
      await file.writeAsBytes(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTokens.colorBgSurface,
            content: Row(
              children: [
                Icon(Icons.check_circle,
                    color: const Color(0xFF2ECC71), size: 18),
                const SizedBox(width: 10),
                const Text('Progress chart saved',
                    style: TextStyle(color: Colors.white)),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }
}
