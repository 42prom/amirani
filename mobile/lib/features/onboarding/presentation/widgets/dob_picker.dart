import 'package:flutter/material.dart';
import 'package:amirani_app/theme/app_theme.dart';

class DobPicker extends StatefulWidget {
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  const DobPicker({super.key, required this.value, required this.onChanged});

  @override
  State<DobPicker> createState() => _DobPickerState();
}

class _DobPickerState extends State<DobPicker> {
  late int _day;
  late int _month;
  late int _year;

  late FixedExtentScrollController _dayCtrl;
  late FixedExtentScrollController _monthCtrl;
  late FixedExtentScrollController _yearCtrl;

  final List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  final int _startYear = 1940;
  int get _endYear => DateTime.now().year - 5;

  int get _daysInMonth => DateUtils.getDaysInMonth(_year, _month);

  @override
  void initState() {
    super.initState();
    final d = widget.value ?? DateTime(1990, 6, 15);
    _day = d.day;
    _month = d.month;
    _year = d.year;

    _dayCtrl = FixedExtentScrollController(initialItem: _day - 1);
    _monthCtrl = FixedExtentScrollController(initialItem: _month - 1);
    _yearCtrl =
        FixedExtentScrollController(initialItem: _year - _startYear);
  }

  @override
  void dispose() {
    _dayCtrl.dispose();
    _monthCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    final clamped = _day.clamp(1, _daysInMonth);
    widget.onChanged(DateTime(_year, _month, clamped));
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required Widget Function(int) itemBuilder,
    required ValueChanged<int> onSelected,
  }) {
    return SizedBox(
      width: 80,
      height: 150,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 42,
        diameterRatio: 1.6,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onSelected,
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, index) {
            if (index < 0 || index >= itemCount) return null;
            return Center(child: itemBuilder(index));
          },
          childCount: itemCount,
        ),
      ),
    );
  }

  TextStyle _itemStyle(bool selected) => TextStyle(
        color: selected ? AppTheme.textPrimary : AppTheme.textSecondary.withValues(alpha: 0.4),
        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        fontSize: selected ? 20 : 15,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Stack(
        children: [
          // Selection highlight
          Center(
            child: Container(
              height: 42,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.primaryBrand.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.primaryBrand.withValues(alpha: 0.25)),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Day
              _wheel(
                controller: _dayCtrl,
                itemCount: 31,
                onSelected: (i) {
                  setState(() => _day = i + 1);
                  _notify();
                },
                itemBuilder: (i) {
                  final selected = i + 1 == _day;
                  return Text(
                    (i + 1).toString().padLeft(2, '0'),
                    style: _itemStyle(selected),
                  );
                },
              ),
              // Divider
              Text('/', style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.3), fontSize: 20)),
              // Month
              _wheel(
                controller: _monthCtrl,
                itemCount: 12,
                onSelected: (i) {
                  setState(() => _month = i + 1);
                  _notify();
                },
                itemBuilder: (i) {
                  final selected = i + 1 == _month;
                  return Text(_months[i], style: _itemStyle(selected));
                },
              ),
              Text('/', style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.3), fontSize: 20)),
              // Year
              _wheel(
                controller: _yearCtrl,
                itemCount: _endYear - _startYear + 1,
                onSelected: (i) {
                  setState(() => _year = _startYear + i);
                  _notify();
                },
                itemBuilder: (i) {
                  final y = _startYear + i;
                  final selected = y == _year;
                  return Text(y.toString(), style: _itemStyle(selected));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
