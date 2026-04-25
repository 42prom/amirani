import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:amirani_app/design_system/tokens/app_tokens.dart';

/// Horizontal scrollable ruler picker.
/// Uses LayoutBuilder so the centre indicator always aligns with the selected
/// tick — correct on every screen size regardless of parent padding.
class RulerPicker extends StatefulWidget {
  final double value;
  final double minValue;
  final double maxValue;
  final double step;
  final int decimalPlaces;
  final ValueChanged<double> onChanged;
  final String unit;
  final double tickSpacing;
  final double height;

  const RulerPicker({
    super.key,
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.onChanged,
    this.step = 1.0,
    this.decimalPlaces = 0,
    this.unit = '',
    this.tickSpacing = 14.0,
    this.height = 88.0,
  });

  @override
  State<RulerPicker> createState() => _RulerPickerState();
}

class _RulerPickerState extends State<RulerPicker> {
  late ScrollController _ctrl;
  bool _isScrolling = false;

  int get _totalTicks =>
      ((widget.maxValue - widget.minValue) / widget.step).round() + 1;

  double _valueToOffset(double value) {
    final index = ((value - widget.minValue) / widget.step).round();
    return index * widget.tickSpacing;
  }

  double _offsetToValue(double offset) {
    final index = (offset / widget.tickSpacing).round();
    return (widget.minValue + index * widget.step)
        .clamp(widget.minValue, widget.maxValue);
  }

  @override
  void initState() {
    super.initState();
    _ctrl = ScrollController(
      initialScrollOffset: _valueToOffset(widget.value),
    );
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
  void didUpdateWidget(RulerPicker old) {
    super.didUpdateWidget(old);
    // Only animate when value changed externally (not by scrolling)
    if (!_isScrolling && old.value != widget.value) {
      final target = _valueToOffset(widget.value);
      if ((_ctrl.offset - target).abs() > widget.step * widget.tickSpacing * 0.4) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_ctrl.hasClients && mounted) {
            _ctrl.animateTo(target,
                duration: const Duration(milliseconds: 180),
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
    // LayoutBuilder gives exact available width — critical for correct centering
    // when the ruler sits inside a padded parent container.
    return LayoutBuilder(builder: (context, constraints) {
      final halfW = constraints.maxWidth / 2;

      return SizedBox(
        height: widget.height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Ruler list ────────────────────────────────────────────
            NotificationListener<ScrollStartNotification>(
              onNotification: (_) {
                _isScrolling = true;
                return false;
              },
              child: NotificationListener<ScrollEndNotification>(
                onNotification: (_) {
                  _isScrolling = false;
                  final snapped =
                      _valueToOffset(_offsetToValue(_ctrl.offset));
                  if ((_ctrl.offset - snapped).abs() > 0.1) {
                    _ctrl.animateTo(snapped,
                        duration: const Duration(milliseconds: 130),
                        curve: Curves.easeOut);
                  }
                  return false;
                },
                child: ListView.builder(
                  controller: _ctrl,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  // halfW from LayoutBuilder — selected tick aligns with indicator
                  padding: EdgeInsets.symmetric(horizontal: halfW),
                  itemCount: _totalTicks,
                  itemBuilder: (context, index) {
                    final tickValue = widget.minValue + index * widget.step;
                    final isMajor = index % 10 == 0;
                    final isMid = (index % 5 == 0) && !isMajor;

                    final tickH = isMajor ? 32.0 : (isMid ? 22.0 : 12.0);
                    final tickColor = isMajor
                        ? Colors.white.withValues(alpha: 0.60)
                        : isMid
                            ? Colors.white.withValues(alpha: 0.28)
                            : Colors.white.withValues(alpha: 0.13);

                    return SizedBox(
                      width: widget.tickSpacing,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.bottomCenter,
                        children: [
                          if (isMajor)
                            Positioned(
                              top: 4,
                              left: -30,
                              right: -30,
                              child: Text(
                                tickValue
                                    .toStringAsFixed(widget.decimalPlaces),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppTokens.colorTextSecondary
                                      .withValues(alpha: 0.65),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              width: 1.5,
                              height: tickH,
                              decoration: BoxDecoration(
                                color: tickColor,
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // ── Left/right fade overlays ───────────────────────────────
            Positioned.fill(
              child: IgnorePointer(
                child: Row(
                  children: [
                    _FadeEdge(fromLeft: true),
                    const Spacer(),
                    _FadeEdge(fromLeft: false),
                  ],
                ),
              ),
            ),

            // ── Centre needle indicator ────────────────────────────────
            IgnorePointer(
              child: Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  // Current value label above needle
                  Positioned(
                    top: 10,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: Text(
                        "${widget.value.toStringAsFixed(widget.decimalPlaces)} ${widget.unit}",
                        key: ValueKey(widget.value),
                        style: const TextStyle(
                          color: AppTokens.colorBrand,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 2,
                        height: 42, // Slightly shorter to make room for Text
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppTokens.colorBrand.withValues(alpha: 0.4),
                              AppTokens.colorBrand,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppTokens.colorBrand.withValues(alpha: 0.6),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: AppTokens.colorBrand,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppTokens.colorBrand.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _FadeEdge extends StatelessWidget {
  final bool fromLeft;
  const _FadeEdge({required this.fromLeft});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: fromLeft ? Alignment.centerLeft : Alignment.centerRight,
          end: fromLeft ? Alignment.centerRight : Alignment.centerLeft,
          colors: [
            AppTokens.colorBgPrimary,
            AppTokens.colorBgPrimary.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
