import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:amirani_app/design_system/tokens/app_tokens.dart';

/// Vertical scrollable ruler.
/// Selected value is always centred at the indicator line.
/// Uses LayoutBuilder so centering is correct on every screen size.
class VerticalRulerPicker extends StatefulWidget {
  final double value;
  final double minValue;
  final double maxValue;
  final double step;
  final int decimalPlaces;
  final ValueChanged<double> onChanged;
  final double tickSpacing; // pixels per step
  final bool isImperial;

  const VerticalRulerPicker({
    super.key,
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.onChanged,
    this.step = 1.0,
    this.decimalPlaces = 0,
    this.tickSpacing = 10.0,
    this.isImperial = false,
  });

  @override
  State<VerticalRulerPicker> createState() => _VerticalRulerPickerState();
}

class _VerticalRulerPickerState extends State<VerticalRulerPicker> {
  late ScrollController _ctrl;
  bool _isScrolling = false;

  int get _totalTicks =>
      ((widget.maxValue - widget.minValue) / widget.step).round() + 1;

  double _valueToOffset(double value) {
    final index = ((widget.maxValue - value) / widget.step).round();
    return index * widget.tickSpacing;
  }

  double _offsetToValue(double offset) {
    final index = (offset / widget.tickSpacing).round();
    return (widget.maxValue - index * widget.step)
        .clamp(widget.minValue, widget.maxValue);
  }

  @override
  void initState() {
    super.initState();
    _ctrl = ScrollController(initialScrollOffset: _valueToOffset(widget.value));
    _ctrl.addListener(_onScroll);
  }

  void _onScroll() {
    final newVal = _offsetToValue(_ctrl.offset);
    if ((newVal - widget.value).abs() >= widget.step * 0.4) {
      HapticFeedback.selectionClick();
      widget.onChanged(newVal);
    }
  }

  @override
  void didUpdateWidget(VerticalRulerPicker old) {
    super.didUpdateWidget(old);
    // Only animate when value changed externally (not by user scrolling)
    if (!_isScrolling && old.value != widget.value) {
      final target = _valueToOffset(widget.value);
      if ((_ctrl.offset - target).abs() > widget.step * 0.4) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_ctrl.hasClients && mounted) {
            _ctrl.animateTo(target,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onScroll);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder gives the exact available height — critical for correct centering
    return LayoutBuilder(builder: (context, constraints) {
      final halfH = constraints.maxHeight / 2;

      return NotificationListener<ScrollStartNotification>(
        onNotification: (_) {
          _isScrolling = true;
          return false;
        },
        child: NotificationListener<ScrollEndNotification>(
          onNotification: (_) {
            _isScrolling = false;
            final snapped = _valueToOffset(_offsetToValue(_ctrl.offset));
            if ((_ctrl.offset - snapped).abs() > 0.1) {
              _ctrl.animateTo(snapped,
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut);
            }
            return false;
          },
          child: Stack(
            alignment: Alignment.centerRight,
            children: [
              // ── Tick list ──────────────────────────────────────────
              ListView.builder(
                controller: _ctrl,
                scrollDirection: Axis.vertical,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                // halfH centers the selected tick at the indicator — correct on all phones
                padding: EdgeInsets.symmetric(vertical: halfH),
                itemCount: _totalTicks,
                itemBuilder: (context, index) {
                  // Ruler top→bottom: top = maxValue, bottom = minValue
                  final tickValue = widget.maxValue - index * widget.step;
                  final isMajor = index % 10 == 0;
                  final isMid = (index % 5 == 0) && !isMajor;
                  final showLabel = isMajor || isMid;

                  final tickW = isMajor ? 22.0 : (isMid ? 16.0 : 8.0);
                  final tickColor = isMajor
                      ? Colors.white.withValues(alpha: 0.60)
                      : isMid
                          ? Colors.white.withValues(alpha: 0.32)
                          : Colors.white.withValues(alpha: 0.15);

                  return SizedBox(
                    height: widget.tickSpacing,
                    child: OverflowBox(
                      maxHeight: double.infinity,
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        height: widget.tickSpacing,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (showLabel)
                              Text(
                                widget.isImperial
                                    ? "${(tickValue / 12).floor()}'${(tickValue % 12).round()}\""
                                    : tickValue
                                        .toStringAsFixed(widget.decimalPlaces),
                                style: TextStyle(
                                  color: isMajor
                                      ? AppTokens.colorTextSecondary
                                          .withValues(alpha: 0.80)
                                      : AppTokens.colorTextSecondary
                                          .withValues(alpha: 0.45),
                                  fontSize: isMajor ? 10 : 9,
                                  fontWeight: isMajor
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  height: 1,
                                ),
                              ),
                            if (showLabel) const SizedBox(width: 4),
                            Container(
                              width: tickW,
                              height: 1.5,
                              decoration: BoxDecoration(
                                color: tickColor,
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                            const SizedBox(width: 3),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              // ── Top fade ──────────────────────────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Container(
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTokens.colorBgPrimary,
                          AppTokens.colorBgPrimary.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Bottom fade ────────────────────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Container(
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          AppTokens.colorBgPrimary,
                          AppTokens.colorBgPrimary.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Centre indicator ───────────────────────────────────
              IgnorePointer(
                child: Center(
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTokens.colorBrand.withValues(alpha: 0),
                              AppTokens.colorBrand.withValues(alpha: 0.9),
                              AppTokens.colorBrand,
                            ],
                            stops: const [0.0, 0.4, 1.0],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppTokens.colorBrand.withValues(alpha: 0.7),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color:
                                  AppTokens.colorBrand.withValues(alpha: 0.3),
                              blurRadius: 18,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                      ),
                      // Current value label precisely on the indicator
                      Positioned(
                        left: -55,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTokens.colorBrand.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: AppTokens.colorBrand
                                    .withValues(alpha: 0.4),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Text(
                            widget.isImperial
                                ? "${(widget.value / 12).floor()}'${(widget.value % 12).round()}\""
                                : "${widget.value.round()}",
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
